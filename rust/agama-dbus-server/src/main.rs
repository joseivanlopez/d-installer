use std::{error::Error, future::pending};
use zbus::{ConnectionBuilder, dbus_interface};

struct Locale {
    locale_id: String,
    keyboard_id: String,
    timezone_id: String
}

#[dbus_interface(name = "org.opensuse.Agama.Locale1")]
impl Locale {
    // Can be `async` as well.
    fn list_locales(&self, locale: &str) -> Vec<(String, String)> {
        let locales = agama_locale_data::get_languages();
        // TODO: localization param
        return locales.language.iter().map(|l| (l.id.clone(), locale.to_string())).collect()
    }

    fn set_locale(&mut self, locale: &str) {
        self.locale_id = locale.to_string();
    }

    fn list_x11_keyboards(&self) -> Vec<(String, String)> {
        let keyboards = agama_locale_data::get_keyboards();
        return keyboards.keyboard.iter().map(|k| (k.id.clone(), k.description.clone())).collect()
    }

    fn set_x11_keyboard(&mut self, keyboard: &str) {
        self.keyboard_id = keyboard.to_string();
    }

    fn set_timezone(&mut self, timezone: &str) {
        self.timezone_id = timezone.to_string();
    }
}

// Although we use `async-std` here, you can use any async runtime of choice.
#[async_std::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let locale = Locale { locale_id: "en".to_string(), keyboard_id: "us".to_string(), timezone_id: "Europe/Prague".to_string() };
    let _conn = ConnectionBuilder::session()? //TODO: use agama bus instead of session one
        .name("org.opensuse.Agama.Locale1")?
        .serve_at("/org/opensuse/Agama/Locale1", locale)?
        .build()
        .await?;

    // Do other things or go to wait forever
    pending::<()>().await;

    Ok(())
}