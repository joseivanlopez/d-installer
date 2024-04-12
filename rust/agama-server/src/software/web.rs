//! This module implements the web API for the software service.
//!
//! The module offers two public functions:
//!
//! * `software_service` which returns the Axum service.
//! * `software_stream` which offers an stream that emits the software events coming from D-Bus.

use crate::{
    error::Error,
    web::{
        common::{issues_router, progress_router, service_status_router, Streams},
        Event,
    },
};
use agama_lib::{
    error::ServiceError,
    product::{Product, ProductClient, RegistrationRequirement, proxies::RegistrationProxy},
    software::{
        proxies::{Software1Proxy, SoftwareProductProxy},
        Pattern, SelectedBy, SoftwareClient, UnknownSelectedBy,
    },
};
use axum::{
    extract::State,
    routing::{get, post, put},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio_stream::{Stream, StreamExt};

#[derive(Clone)]
struct SoftwareState<'a> {
    product: ProductClient<'a>,
    software: SoftwareClient<'a>,
}

/// Software service configuration (product, patterns, etc.).
#[derive(Clone, Serialize, Deserialize, utoipa::ToSchema)]
pub struct SoftwareConfig {
    /// A map where the keys are the pattern names and the values whether to install them or not.
    patterns: Option<HashMap<String, bool>>,
    /// Name of the product to install.
    product: Option<String>,
}

/// Returns an stream that emits software related events coming from D-Bus.
///
/// It emits the Event::ProductChanged and Event::PatternsChanged events.
///
/// * `connection`: D-Bus connection to listen for events.
pub async fn software_streams(
    dbus: zbus::Connection,
) -> Result<Streams, Error> {
    let result: Streams = vec![
        (
            "patterns_changed",
            Box::pin(patterns_changed_stream(dbus.clone()).await?),
        ),
        (
            "product_changed",
            Box::pin(product_changed_stream(dbus.clone()).await?),
        ),
        (
            "registration_requirement_changed",
            Box::pin(registration_requirement_changed_stream(dbus.clone()).await?),
        ),
        (
            "registration_code_changed",
            Box::pin(registration_code_changed_stream(dbus.clone()).await?),
        ),
        (
            "registration_email_changed",
            Box::pin(registration_email_changed_stream(dbus.clone()).await?),
        ),
    ];

    Ok(result)
}

async fn product_changed_stream(
    dbus: zbus::Connection,
) -> Result<impl Stream<Item = Event>, Error> {
    let proxy = SoftwareProductProxy::new(&dbus).await?;
    let stream = proxy
        .receive_selected_product_changed()
        .await
        .then(|change| async move {
            if let Ok(id) = change.get().await {
                return Some(Event::ProductChanged { id });
            }
            None
        })
        .filter_map(|e| e);
    Ok(stream)
}

async fn patterns_changed_stream(
    dbus: zbus::Connection,
) -> Result<impl Stream<Item = Event>, Error> {
    let proxy = Software1Proxy::new(&dbus).await?;
    let stream = proxy
        .receive_selected_patterns_changed()
        .await
        .then(|change| async move {
            if let Ok(patterns) = change.get().await {
                return match reason_to_selected_by(patterns) {
                    Ok(patterns) => Some(patterns),
                    Err(error) => {
                        log::warn!("Ignoring the list of changed patterns. Error: {}", error);
                        None
                    }
                };
            }
            None
        })
        .filter_map(|e| e.map(|patterns| Event::SoftwareProposalChanged { patterns }));
    Ok(stream)
}

async fn registration_requirement_changed_stream(dbus: zbus::Connection,
) -> Result<impl Stream<Item = Event>, Error> {
    // TODO: move registration requirement to product in dbus and so just one event will be needed.
    let proxy = RegistrationProxy::new(&dbus).await?;
    let stream = proxy
        .receive_requirement_changed()
        .await
        .then(|change| async move {
            if let Ok(id) = change.get().await {
                // unwrap is safe as possible numbers is send by our controlled dbus
                return Some(Event::RegistrationRequirementChanged { requirement: id.try_into().unwrap() });
            }
            None
        })
        .filter_map(|e| e);
    Ok(stream)
}

async fn registration_email_changed_stream(dbus: zbus::Connection,
) -> Result<impl Stream<Item = Event>, Error> {
    let proxy = RegistrationProxy::new(&dbus).await?;
    let stream = proxy
        .receive_email_changed()
        .await
        .then(|change| async move {
            if let Ok(_id) = change.get().await {
                // TODO: add to stream also proxy and return whole cached registration info
                return Some(Event::RegistrationChanged);
            }
            None
        })
        .filter_map(|e| e);
    Ok(stream)
}

async fn registration_code_changed_stream(dbus: zbus::Connection,
) -> Result<impl Stream<Item = Event>, Error> {
    let proxy = RegistrationProxy::new(&dbus).await?;
    let stream = proxy
        .receive_reg_code_changed()
        .await
        .then(|change| async move {
            if let Ok(_id) = change.get().await {
                return Some(Event::RegistrationChanged);
            }
            None
        })
        .filter_map(|e| e);
    Ok(stream)
}

// Returns a hash replacing the selection "reason" from D-Bus with a SelectedBy variant.
fn reason_to_selected_by(
    patterns: HashMap<String, u8>,
) -> Result<HashMap<String, SelectedBy>, UnknownSelectedBy> {
    let mut selected: HashMap<String, SelectedBy> = HashMap::new();
    for (id, reason) in patterns {
        match SelectedBy::try_from(reason) {
            Ok(selected_by) => selected.insert(id, selected_by),
            Err(e) => return Err(e),
        };
    }
    Ok(selected)
}

/// Sets up and returns the axum service for the software module.
pub async fn software_service(dbus: zbus::Connection) -> Result<Router, ServiceError> {
    const DBUS_SERVICE: &str = "org.opensuse.Agama.Software1";
    const DBUS_PATH: &str = "/org/opensuse/Agama/Software1";
    const DBUS_PRODUCT_PATH: &str = "/org/opensuse/Agama/Software1/Product";

    let status_router = service_status_router(&dbus, DBUS_SERVICE, DBUS_PATH).await?;
    let progress_router = progress_router(&dbus, DBUS_SERVICE, DBUS_PATH).await?;
    let software_issues = issues_router(&dbus, DBUS_SERVICE, DBUS_PATH).await?;
    let product_issues = issues_router(&dbus, DBUS_SERVICE, DBUS_PRODUCT_PATH).await?;

    let product = ProductClient::new(dbus.clone()).await?;
    let software = SoftwareClient::new(dbus).await?;
    let state = SoftwareState { product, software };
    let router = Router::new()
        .route("/patterns", get(patterns))
        .route("/products", get(products))
        .route(
            "/registration",
            get(get_registration).post(register).delete(deregister),
        )
        .route("/proposal", get(proposal))
        .route("/config", put(set_config).get(get_config))
        .route("/probe", post(probe))
        .merge(status_router)
        .merge(progress_router)
        .nest("/issues/product", product_issues)
        .nest("/issues/software", software_issues)
        .with_state(state);
    Ok(router)
}

/// Returns the list of available products.
///
/// * `state`: service state.
#[utoipa::path(get, path = "/software/products", responses(
    (status = 200, description = "List of known products", body = Vec<Product>),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn products(State(state): State<SoftwareState<'_>>) -> Result<Json<Vec<Product>>, Error> {
    let products = state.product.products().await?;
    Ok(Json(products))
}

/// Information about registration configuration (product, patterns, etc.).
#[derive(Clone, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RegistrationInfo {
    /// Registration key. Empty value mean key not used or not registered.
    key: String,
    /// Registration email. Empty value mean email not used or not registered.
    email: String,
    /// if registration is required, optional or not needed for current product.
    /// Change only if selected product is changed.
    requirement: RegistrationRequirement,
}

/// returns registration info
///
/// * `state`: service state.
#[utoipa::path(get, path = "/software/registration", responses(
    (status = 200, description = "registration configuration", body = RegistrationInfo),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn get_registration(
    State(state): State<SoftwareState<'_>>,
) -> Result<Json<RegistrationInfo>, Error> {
    let result = RegistrationInfo {
        key: state.product.registration_code().await?,
        email: state.product.email().await?,
        requirement: state.product.registration_requirement().await?,
    };
    Ok(Json(result))
}

/// Software service configuration (product, patterns, etc.).
#[derive(Clone, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RegistrationParams {
    /// Registration key.
    key: String,
    /// Registration email.
    email: String,
}

/// Register product
///
/// * `state`: service state.
#[utoipa::path(post, path = "/software/registration", responses(
    (status = 200, description = "registration successfull"),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn register(
    State(state): State<SoftwareState<'_>>,
    Json(config): Json<RegistrationParams>,
) -> Result<Json<()>, Error> {
    state.product.register(&config.key, &config.email).await?;
    Ok(Json(()))
}

/// Deregister product
///
/// * `state`: service state.
#[utoipa::path(delete, path = "/software/registration", responses(
    (status = 200, description = "deregistration successfull"),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn deregister(State(state): State<SoftwareState<'_>>) -> Result<Json<()>, Error> {
    state.product.deregister().await?;
    Ok(Json(()))
}

/// Returns the list of software patterns.
///
/// * `state`: service state.
#[utoipa::path(get, path = "/software/patterns", responses(
    (status = 200, description = "List of known software patterns", body = Vec<Pattern>),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn patterns(State(state): State<SoftwareState<'_>>) -> Result<Json<Vec<Pattern>>, Error> {
    let patterns = state.software.patterns(true).await?;
    Ok(Json(patterns))
}

/// Sets the software configuration.
///
/// * `state`: service state.
/// * `config`: software configuration.
#[utoipa::path(put, path = "/software/config", responses(
    (status = 200, description = "Set the software configuration"),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn set_config(
    State(state): State<SoftwareState<'_>>,
    Json(config): Json<SoftwareConfig>,
) -> Result<(), Error> {
    if let Some(product) = config.product {
        state.product.select_product(&product).await?;
    }

    if let Some(patterns) = config.patterns {
        state.software.select_patterns(patterns).await?;
    }

    Ok(())
}

/// Returns the software configuration.
///
/// * `state` : service state.
#[utoipa::path(get, path = "/software/config", responses(
    (status = 200, description = "Software configuration", body = SoftwareConfig),
    (status = 400, description = "The D-Bus service could not perform the action")
))]
async fn get_config(State(state): State<SoftwareState<'_>>) -> Result<Json<SoftwareConfig>, Error> {
    let product = state.product.product().await?;
    let product = if product.is_empty() {
        None
    } else {
        Some(product)
    };
    let patterns = state
        .software
        .user_selected_patterns()
        .await?
        .into_iter()
        .map(|p| (p, true))
        .collect();
    let config = SoftwareConfig {
        patterns: Some(patterns),
        product,
    };
    Ok(Json(config))
}

#[derive(Serialize, utoipa::ToSchema)]
/// Software proposal information.
pub struct SoftwareProposal {
    /// Space required for installation. It is returned as a formatted string which includes
    /// a number and a unit (e.g., "GiB").
    size: String,
    /// Patterns selection. It is respresented as a hash map where the key is the pattern's name
    /// and the value why the pattern is selected.
    patterns: HashMap<String, SelectedBy>,
}

/// Returns the proposal information.
///
/// At this point, only the required space is reported.
#[utoipa::path(
    get, path = "/software/proposal", responses(
        (status = 200, description = "Software proposal", body = SoftwareProposal)
))]
async fn proposal(State(state): State<SoftwareState<'_>>) -> Result<Json<SoftwareProposal>, Error> {
    let size = state.software.used_disk_space().await?;
    let patterns = state.software.selected_patterns().await?;
    let proposal = SoftwareProposal { size, patterns };
    Ok(Json(proposal))
}

/// Returns the proposal information.
///
/// At this point, only the required space is reported.
#[utoipa::path(
    post, path = "/software/probe", responses(
        (status = 200, description = "Read repositories data"),
        (status = 400, description = "The D-Bus service could not perform the action
")
))]
async fn probe(State(state): State<SoftwareState<'_>>) -> Result<Json<()>, Error> {
    state.software.probe().await?;
    Ok(Json(()))
}
