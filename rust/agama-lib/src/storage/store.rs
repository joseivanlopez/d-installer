//! Implements the store for the storage settings.

use super::StorageClient;
use crate::error::ServiceError;
use crate::install_settings::InstallSettings;
use zbus::Connection;

/// Loads and stores the storage settings from/to the D-Bus service.
///
// TODO: load from D-Bus, generating "storage" or "storage_autoyast" settings.
pub struct StorageStore<'a> {
    storage_client: StorageClient<'a>,
}

impl<'a> StorageStore<'a> {
    pub async fn new(connection: Connection) -> Result<StorageStore<'a>, ServiceError> {
        Ok(Self {
            storage_client: StorageClient::new(connection).await?,
        })
    }

    pub async fn store(&self, settings: &InstallSettings) -> Result<(), ServiceError> {
        self.storage_client.load_config(settings).await?;
        Ok(())
    }
}
