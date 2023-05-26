use agama_lib::error::ServiceError;
use parking_lot::Mutex;
use uuid::Uuid;

use crate::{action::Action, dbus::interfaces, model::*};
use std::collections::HashMap;
use std::sync::mpsc::Sender;
use std::sync::Arc;

const CONNECTIONS_PATH: &str = "/org/opensuse/Agama/Network1/connections";
const DEVICES_PATH: &str = "/org/opensuse/Agama/Network1/devices";

/// Handle the objects in the D-Bus tree for the network state
pub struct Tree {
    connection: zbus::Connection,
    actions: Sender<Action>,
    objects: Arc<Mutex<ObjectsRegistry>>,
}

impl Tree {
    /// Creates a new tree handler.
    ///
    /// * `connection`: D-Bus connection to use.
    /// * `actions`: sending-half of a channel to send actions.
    pub fn new(connection: zbus::Connection, actions: Sender<Action>) -> Self {
        Self {
            connection,
            actions,
            objects: Default::default(),
        }
    }

    /// Refreshes the list of connections.
    ///
    /// TODO: re-creating the tree is kind of brute-force and it sends signals about
    /// adding/removing interfaces. We should add/update/delete objects as needed.
    ///
    /// * `connections`: list of connections.
    pub async fn set_connections(
        &self,
        connections: &Vec<Connection>,
    ) -> Result<(), ServiceError> {
        self.remove_connections().await?;
        self.add_connections(connections).await?;
        Ok(())
    }

    /// Refreshes the list of devices.
    ///
    /// * `devices`: list of devices.
    pub async fn set_devices(&mut self, devices: &Vec<Device>) -> Result<(), ServiceError> {
        self.remove_devices().await?;
        self.add_devices(devices).await?;
        Ok(())
    }

    /// Adds devices to the D-Bus tree.
    ///
    /// * `devices`: list of devices.
    pub async fn add_devices(&mut self, devices: &Vec<Device>) -> Result<(), ServiceError> {
        for (i, dev) in devices.iter().enumerate() {
            let path = format!("{}/{}", DEVICES_PATH, i);
            self.add_interface(&path, interfaces::Device::new(dev.clone()))
                .await?;
            let mut objects = self.objects.lock();
            objects.register_device(&dev.name, &path);
        }

        self.add_interface(
            DEVICES_PATH,
            interfaces::Devices::new(Arc::clone(&self.objects)),
        )
        .await?;

        Ok(())
    }

    /// Adds a connection to the D-Bus tree.
    ///
    /// * `connection`: connection to add.
    pub async fn add_connection(&self, conn: &Connection) -> Result<(), ServiceError> {
        let mut objects = self.objects.lock();

        let path = format!("{}/{}", CONNECTIONS_PATH, objects.connections.len());
        let cloned = Arc::new(Mutex::new(conn.clone()));
        self.add_interface(&path, interfaces::Connection::new(Arc::clone(&cloned)))
            .await?;

        self.add_interface(
            &path,
            interfaces::Ipv4::new(self.actions.clone(), Arc::clone(&cloned)),
        )
        .await?;

        if let Connection::Wireless(_) = conn {
            self.add_interface(
                &path,
                interfaces::Wireless::new(self.actions.clone(), Arc::clone(&cloned)),
            )
            .await?;
        }

        objects.register_connection(conn.uuid(), &path);
        Ok(())
    }

    /// Removes a connection from the tree
    ///
    /// * `uuid`: UUID of the connection to remove.
    pub async fn remove_connection(&mut self, uuid: Uuid) -> Result<(), ServiceError> {
        let mut objects = self.objects.lock();
        let Some(path) = objects.connection_path(uuid) else {
            return Ok(())
        };
        self.remove_connection_on(path).await?;
        objects.deregister_connection(uuid).unwrap();
        Ok(())
    }

    /// Adds connections to the D-Bus tree.
    ///
    /// * `connections`: list of connections.
    async fn add_connections(&self, connections: &Vec<Connection>) -> Result<(), ServiceError> {
        for conn in connections.iter() {
            self.add_connection(conn).await?;
        }

        self.add_interface(
            CONNECTIONS_PATH,
            interfaces::Connections::new(Arc::clone(&self.objects), self.actions.clone()),
        )
        .await?;

        Ok(())
    }

    /// Clears all the connections from the tree.
    async fn remove_connections(&self) -> Result<(), ServiceError> {
        let mut objects = self.objects.lock();
        for path in objects.connections.values() {
            self.remove_connection_on(path.as_str()).await?;
        }
        objects.connections.clear();
        Ok(())
    }

    /// Clears all the devices from the tree.
    async fn remove_devices(&mut self) -> Result<(), ServiceError> {
        let object_server = self.connection.object_server();
        let mut objects = self.objects.lock();
        for path in objects.devices.values() {
            object_server
                .remove::<interfaces::Device, _>(path.as_str())
                .await?;
        }
        objects.devices.clear();
        Ok(())
    }

    /// Removes a connection object on the given path
    ///
    /// * `path`: connection D-Bus path.
    async fn remove_connection_on(&self, path: &str) -> Result<(), ServiceError> {
        let object_server = self.connection.object_server();
        _ = object_server.remove::<interfaces::Wireless, _>(path).await;
        object_server.remove::<interfaces::Ipv4, _>(path).await?;
        object_server
            .remove::<interfaces::Connection, _>(path)
            .await?;
        Ok(())
    }

    async fn add_interface<T>(&self, path: &str, iface: T) -> Result<bool, ServiceError>
    where
        T: zbus::Interface,
    {
        let object_server = self.connection.object_server();
        Ok(object_server.at(path.clone(), iface).await?)
    }
}

/// Objects paths for known devices and connections
#[derive(Debug, Default)]
pub struct ObjectsRegistry {
    pub devices: HashMap<String, String>,
    pub connections: HashMap<Uuid, String>,
}

impl ObjectsRegistry {
    /// Registers a network device.
    ///
    /// * `name`: device name.
    /// * `path`: object path.
    pub fn register_device(&mut self, name: &str, path: &str) {
        self.devices.insert(name.to_string(), path.to_string());
    }

    /// Registers a network connection.
    ///
    /// * `uuid`: connection UUID.
    /// * `path`: object path.
    pub fn register_connection(&mut self, uuid: Uuid, path: &str) {
        self.connections.insert(uuid, path.to_string());
    }

    /// Returns the path for a connection.
    ///
    /// * `uuid`: connection UUID.
    pub fn connection_path(&self, uuid: Uuid) -> Option<&str> {
        self.connections.get(&uuid).map(|p| p.as_str())
    }

    /// Deregisters a network connection.
    ///
    /// * `uuid`: connection UUID.
    pub fn deregister_connection(&mut self, uuid: Uuid) -> Option<String> {
        self.connections.remove(&uuid)
    }

    /// Returns all devices paths.
    pub fn devices_paths(&self) -> Vec<String> {
        self.devices.values().map(|p| p.to_string()).collect()
    }

    /// Returns all connection paths.
    pub fn connections_paths(&self) -> Vec<String> {
        self.connections.values().map(|p| p.to_string()).collect()
    }
}
