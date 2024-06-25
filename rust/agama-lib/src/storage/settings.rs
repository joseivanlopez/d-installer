//! Representation of the storage settings

use serde::{Deserialize, Serialize};
use serde_json::value::RawValue;
use crate::install_settings::InstallSettings;

/// Storage settings for installation
#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StorageSettings {
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub storage: Option<Box<RawValue>>,
    #[serde(default, rename = "legacyAutoyastStorage")]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub storage_autoyast: Option<Box<RawValue>>,
}

impl From<&InstallSettings> for StorageSettings {
    fn from(install_settings: &InstallSettings) -> Self {
        StorageSettings {
            storage: install_settings.storage.clone(),
            storage_autoyast: install_settings.storage_autoyast.clone(),
        }
    }
}
