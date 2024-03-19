use agama_dbus_server::{
    l10n::helpers,
    web::{self, run_monitor},
};
use axum::{
    http::{Request, Response},
    Router,
};
use clap::{Args, Parser, Subcommand};
use futures_util::pin_mut;
use hyper::body::Incoming;
use hyper_util::rt::{TokioExecutor, TokioIo};
use openssl::ssl::{Ssl, SslAcceptor, SslFiletype, SslMethod};
use std::process::{ExitCode, Termination};
use std::{path::PathBuf, pin::Pin};
use tokio::sync::broadcast::channel;
use tokio_openssl::SslStream;
use tower::Service;
use tracing_subscriber::prelude::*;
use utoipa::OpenApi;

#[derive(Subcommand, Debug)]
enum Commands {
    /// Start the API server.
    Serve(ServeArgs),
    /// Display the API documentation in OpenAPI format.
    Openapi,
}

#[derive(Parser, Debug)]
#[command(
    version,
    about = "Starts the Agama web-based API.",
    long_about = None)]
struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Args, Debug)]
struct ServeArgs {
    // Address/port to listen on (":::3000" listens for both IPv6 and IPv4
    // connections unless manually disabled in /proc/sys/net/ipv6/bindv6only)
    #[arg(long, default_value = ":::3000", help = "Primary address to listen on")]
    address: String,
    #[arg(
        long,
        default_value = "",
        help = "Optional secondary address to listen on"
    )]
    address2: String,
    #[arg(
        long,
        default_value = "",
        help = "Path to the SSL private key file in PEM format"
    )]
    key: String,
    #[arg(
        long,
        default_value = "",
        help = "Path to the SSL certificate file in PEM format"
    )]
    cert: String,
}

/// Checks whether the connection uses SSL or not
async fn is_ssl_stream(stream: &tokio::net::TcpStream) -> bool {
    // a buffer for reading the first byte from the TCP connection
    let mut buf = [0u8; 1];

    // peek() receives the data without removing it from the stream,
    // the data is not consumed, it will be read from the stream again later
    stream
        .peek(&mut buf)
        .await
        // SSL3.0/TLS1.x starts with byte 0x16
        // SSL2 starts with 0x80 (but should not be used as it is considered)
        // see https://stackoverflow.com/q/3897883
        // otherwise consider the stream as a plain HTTP stream possibly starting with
        // "GET ... HTTP/1.1" or "POST ... HTTP/1.1" or a similar line
        .is_ok_and(|_| buf[0] == 0x16u8 || buf[0] == 0x80u8)
}

/// Builds an SSL acceptor using a provided SSL certificate or generates a self-signed one
fn create_ssl_acceptor(
    cert_file: &String,
    key_file: &String,
) -> Result<SslAcceptor, openssl::error::ErrorStack> {
    let mut tls_builder = SslAcceptor::mozilla_modern_v5(SslMethod::tls_server())?;

    if cert_file.is_empty() && key_file.is_empty() {
        let (cert, key) = agama_dbus_server::cert::create_certificate()?;
        tracing::info!("Generated self signed certificate: {:#?}", cert);
        tls_builder.set_private_key(key.as_ref())?;
        tls_builder.set_certificate(cert.as_ref())?;

        // for debugging you might dump the certificate to a file:
        // use std::io::Write;
        // let mut cert_file = std::fs::File::create("agama_cert.pem").unwrap();
        // let mut key_file = std::fs::File::create("agama_key.pem").unwrap();
        // cert_file.write_all(cert.to_pem().unwrap().as_ref()).unwrap();
        // key_file.write_all(key.private_key_to_pem_pkcs8().unwrap().as_ref()).unwrap();
    } else {
        tracing::info!("Loading PEM certificate: {}", cert_file);
        tls_builder.set_certificate_file(PathBuf::from(cert_file), SslFiletype::PEM)?;

        tracing::info!("Loading PEM key: {}", key_file);
        tls_builder.set_private_key_file(PathBuf::from(key_file), SslFiletype::PEM)?;
    }

    // check that the key belongs to the certificate
    tls_builder.check_private_key()?;

    Ok(tls_builder.build())
}

/// Builds a response for the HTTP -> HTTPS redirection
/// returns (HTTP response status code) 308 permanent redirect
fn redirect_https(host: &str, uri: &hyper::Uri) -> Response<String> {
    let builder = Response::builder()
        // build the redirection target URL
        .header("Location", format!("https://{}{}", host, uri))
        .status(hyper::StatusCode::PERMANENT_REDIRECT);

    // according to documentation this can fail only if builder was previosly fed with data
    // which failed to parse into an internal representation (e.g. invalid header)
    builder
        .body(String::from(""))
        .expect("Failed to create redirection request")
}

/// Builds an error response for the HTTP -> HTTPS redirection when we cannot build
/// the redirect response from the original request
/// returns error 400
fn redirect_error() -> Response<String> {
    let builder = Response::builder().status(hyper::StatusCode::BAD_REQUEST);

    let msg = "HTTP protocol is not allowed for external requests, please use HTTPS.\n";
    // according to documentation this can fail only if builder was previosly fed with data
    // which failed to parse into an internal representation (e.g. invalid header)
    builder
        .body(String::from(msg))
        .expect("Failed to create an error response")
}

/// Builds a router for the HTTP -> HTTPS redirection
/// if the redirection URL cannot be built from the original request it returns error 400
/// instead of the redirection
fn https_redirect() -> Router {
    // see https://docs.rs/axum/latest/axum/routing/struct.Router.html#example
    let redirect_service = tower::service_fn(|req: axum::extract::Request| async move {
        if let Some(host) = req.headers().get("host").and_then(|h| h.to_str().ok()) {
            Ok(redirect_https(host, req.uri()))
        } else {
            Ok(redirect_error())
        }
    });

    Router::new()
        // the wildcard path below does not match an empty path, we need to match it explicitly
        .route_service("/", redirect_service)
        .route_service("/*path", redirect_service)
}

/// Starts the web server
async fn start_server(address: String, service: Router, ssl_acceptor: SslAcceptor) {
    tracing::info!("Starting Agama web server at {}", address);

    // see https://github.com/tokio-rs/axum/blob/main/examples/low-level-openssl/src/main.rs
    // how to use axum with openSSL
    let listener = tokio::net::TcpListener::bind(&address)
        .await
        .unwrap_or_else(|_| panic!("could not listen on {}", &address));

    pin_mut!(listener);

    let redirector = https_redirect();

    loop {
        let tower_service = service.clone();
        let redirector_service = redirector.clone();
        let tls_acceptor = ssl_acceptor.clone();

        // Wait for a new tcp connection; if it fails we cannot do much, so print an error and die
        let (tcp_stream, addr) = listener
            .accept()
            .await
            .expect("Failed to open port for listening");

        tokio::spawn(async move {
            if is_ssl_stream(&tcp_stream).await {
                // handle HTTPS connection
                let ssl = Ssl::new(tls_acceptor.context()).unwrap();
                let mut tls_stream = SslStream::new(ssl, tcp_stream).unwrap();
                if let Err(err) = SslStream::accept(Pin::new(&mut tls_stream)).await {
                    tracing::error!("Error during TSL handshake from {}: {}", addr, err);
                }

                let stream = TokioIo::new(tls_stream);
                let hyper_service =
                    hyper::service::service_fn(move |request: Request<Incoming>| {
                        tower_service.clone().call(request)
                    });

                let ret = hyper_util::server::conn::auto::Builder::new(TokioExecutor::new())
                    .serve_connection_with_upgrades(stream, hyper_service)
                    .await;

                if let Err(err) = ret {
                    tracing::error!("Error serving connection from {}: {}", addr, err);
                }
            } else {
                // handle HTTP connection
                let stream = TokioIo::new(tcp_stream);
                let hyper_service =
                    hyper::service::service_fn(move |request: Request<Incoming>| {
                        // check if it is local connection or external
                        // the to_canonical() converts IPv4-mapped IPv6 addresses
                        // to plain IPv4, then is_loopback() works correctly for the IPv4 connections
                        if addr.ip().to_canonical().is_loopback() {
                            // accept plain HTTP on the local connection
                            tower_service.clone().call(request)
                        } else {
                            // redirect external connections to HTTPS
                            redirector_service.clone().call(request)
                        }
                    });

                let ret = hyper_util::server::conn::auto::Builder::new(TokioExecutor::new())
                    .serve_connection_with_upgrades(stream, hyper_service)
                    .await;

                if let Err(err) = ret {
                    tracing::error!("Error serving connection from {}: {}", addr, err);
                }
            }
        });
    }
}

/// Start serving the API.
async fn serve_command(
    address: &str,
    address2: &str,
    cert: &String,
    key: &String,
) -> anyhow::Result<()> {
    let journald = tracing_journald::layer().expect("could not connect to journald");
    tracing_subscriber::registry().with(journald).init();

    let (tx, _) = channel(16);
    run_monitor(tx.clone()).await?;

    let service = if let Ok(config) = web::ServiceConfig::load() {
        web::service(config, tx)
    } else {
        return Err(anyhow::anyhow!("Failed to load the service configuration"));
    };
    let ssl_acceptor = if let Ok(ssl_acceptor) = create_ssl_acceptor(cert, key) {
        ssl_acceptor
    } else {
        return Err(anyhow::anyhow!("SSL initialization failed"));
    };

    let mut servers = vec![];
    servers.push(tokio::spawn(start_server(
        address.to_owned(),
        service.clone(),
        ssl_acceptor.clone(),
    )));

    // optionally listen on the secondary address/port
    if !address2.is_empty() {
        servers.push(tokio::spawn(start_server(
            address2.to_owned(),
            service.clone(),
            ssl_acceptor.clone(),
        )));
    }

    futures_util::future::join_all(servers).await;

    Ok(())
}

/// Display the API documentation in OpenAPI format.
fn openapi_command() -> anyhow::Result<()> {
    println!("{}", web::ApiDoc::openapi().to_pretty_json().unwrap());
    Ok(())
}

async fn run_command(cli: Cli) -> anyhow::Result<()> {
    match cli.command {
        Commands::Serve(options) => serve_command(
            &options.address,
            &options.address2,
            &options.cert,
            &options.key,
        ).await,
        Commands::Openapi => openapi_command(),
    }
}

/// Represents the result of execution.
pub enum CliResult {
    /// Successful execution.
    Ok = 0,
    /// Something went wrong.
    Error = 1,
}

impl Termination for CliResult {
    fn report(self) -> ExitCode {
        ExitCode::from(self as u8)
    }
}

#[tokio::main]
async fn main() -> CliResult {
    let cli = Cli::parse();
    _ = helpers::init_locale();

    if let Err(error) = run_command(cli).await {
        eprintln!("{:?}", error);
        return CliResult::Error;
    }

    CliResult::Ok
}
