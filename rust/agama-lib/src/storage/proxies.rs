// Copyright (c) [2024] SUSE LLC
//
// All Rights Reserved.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 2 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, contact SUSE LLC.
//
// To contact SUSE LLC about this file by physical or electronic mail, you may
// find current contact information at www.suse.com.

//! D-Bus interface proxies for interfaces implemented by objects in the storage service.
//!
//! This code was generated by `zbus-xmlgen` `3.1.1` from DBus introspection data.
use zbus::dbus_proxy;

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait Storage1 {
    /// Finish method
    fn finish(&self) -> zbus::Result<()>;

    /// Install method
    fn install(&self) -> zbus::Result<()>;

    /// Probe method
    fn probe(&self) -> zbus::Result<()>;

    /// Set the storage config according to the JSON schema
    fn set_config(&self, settings: &str) -> zbus::Result<u32>;

    /// Set the storage config according to the JSON schema
    fn set_incremental_config(&self, settings: &str) -> zbus::Result<u32>;

    /// Get the current storage config according to the JSON schema
    fn get_config(&self) -> zbus::Result<String>;

    /// Get the storage config model according to the JSON schema
    fn get_config_model(&self) -> zbus::Result<String>;

    /// DeprecatedSystem property
    #[dbus_proxy(property)]
    fn deprecated_system(&self) -> zbus::Result<bool>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.Proposal.Calculator",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait ProposalCalculator {
    /// Calculate guided proposal
    fn calculate(
        &self,
        settings: std::collections::HashMap<&str, zbus::zvariant::Value<'_>>,
    ) -> zbus::Result<u32>;

    /// DefaultVolume method
    fn default_volume(
        &self,
        mount_path: &str,
    ) -> zbus::Result<std::collections::HashMap<String, zbus::zvariant::OwnedValue>>;

    /// AvailableDevices property
    #[dbus_proxy(property)]
    fn available_devices(&self) -> zbus::Result<Vec<zbus::zvariant::OwnedObjectPath>>;

    /// EncryptionMethods property
    #[dbus_proxy(property)]
    fn encryption_methods(&self) -> zbus::Result<Vec<String>>;

    /// ProductMountPoints property
    #[dbus_proxy(property)]
    fn product_mount_points(&self) -> zbus::Result<Vec<String>>;

    /// Proposal result
    fn result(&self)
        -> zbus::Result<std::collections::HashMap<String, zbus::zvariant::OwnedValue>>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.Devices",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait Devices {
    /// Actions property
    #[dbus_proxy(property)]
    fn actions(
        &self,
    ) -> zbus::Result<Vec<std::collections::HashMap<String, zbus::zvariant::OwnedValue>>>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.Proposal",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1/Proposal"
)]
trait Proposal {
    /// Settings property
    #[dbus_proxy(property)]
    fn settings(
        &self,
    ) -> zbus::Result<std::collections::HashMap<String, zbus::zvariant::OwnedValue>>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.ISCSI.Initiator",
    default_service = "org.opensuse.Agama.Storage1",
    assume_defaults = true
)]
trait Initiator {
    /// Delete method
    fn delete(&self, node: &zbus::zvariant::ObjectPath<'_>) -> zbus::Result<u32>;

    /// Discover method
    fn discover(
        &self,
        address: &str,
        port: u32,
        options: std::collections::HashMap<&str, &zbus::zvariant::Value<'_>>,
    ) -> zbus::Result<u32>;

    /// IBFT property
    #[dbus_proxy(property, name = "IBFT")]
    fn ibft(&self) -> zbus::Result<bool>;

    /// InitiatorName property
    #[dbus_proxy(property)]
    fn initiator_name(&self) -> zbus::Result<String>;
    #[dbus_proxy(property)]
    fn set_initiator_name(&self, value: &str) -> zbus::Result<()>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.ISCSI.Node",
    default_service = "org.opensuse.Agama.Storage1",
    assume_defaults = true
)]
trait Node {
    /// Login method
    fn login(
        &self,
        options: std::collections::HashMap<&str, &zbus::zvariant::Value<'_>>,
    ) -> zbus::Result<u32>;

    /// Logout method
    fn logout(&self) -> zbus::Result<u32>;

    /// Address property
    #[dbus_proxy(property)]
    fn address(&self) -> zbus::Result<String>;

    /// Connected property
    #[dbus_proxy(property)]
    fn connected(&self) -> zbus::Result<bool>;

    /// IBFT property
    #[dbus_proxy(property, name = "IBFT")]
    fn ibft(&self) -> zbus::Result<bool>;

    /// Interface property
    #[dbus_proxy(property)]
    fn interface(&self) -> zbus::Result<String>;

    /// Port property
    #[dbus_proxy(property)]
    fn port(&self) -> zbus::Result<u32>;

    /// Startup property
    #[dbus_proxy(property)]
    fn startup(&self) -> zbus::Result<String>;
    #[dbus_proxy(property)]
    fn set_startup(&self, value: &str) -> zbus::Result<()>;

    /// Target property
    #[dbus_proxy(property)]
    fn target(&self) -> zbus::Result<String>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.DASD.Manager",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait DASDManager {
    /// Disable method
    fn disable(&self, devices: &[&zbus::zvariant::ObjectPath<'_>]) -> zbus::Result<u32>;

    /// Enable method
    fn enable(&self, devices: &[&zbus::zvariant::ObjectPath<'_>]) -> zbus::Result<u32>;

    /// Format method
    fn format(
        &self,
        devices: &[&zbus::zvariant::ObjectPath<'_>],
    ) -> zbus::Result<(u32, zbus::zvariant::OwnedObjectPath)>;

    /// Probe method
    fn probe(&self) -> zbus::Result<()>;

    /// SetDiag method
    fn set_diag(
        &self,
        devices: &[&zbus::zvariant::ObjectPath<'_>],
        diag: bool,
    ) -> zbus::Result<u32>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.DASD.Device",
    default_service = "org.opensuse.Agama.Storage1",
    assume_defaults = true
)]
trait DASDDevice {
    /// AccessType property
    #[dbus_proxy(property)]
    fn access_type(&self) -> zbus::Result<String>;

    /// DeviceName property
    #[dbus_proxy(property)]
    fn device_name(&self) -> zbus::Result<String>;

    /// Diag property
    #[dbus_proxy(property)]
    fn diag(&self) -> zbus::Result<bool>;

    /// Enabled property
    #[dbus_proxy(property)]
    fn enabled(&self) -> zbus::Result<bool>;

    /// Formatted property
    #[dbus_proxy(property)]
    fn formatted(&self) -> zbus::Result<bool>;

    /// Id property
    #[dbus_proxy(property)]
    fn id(&self) -> zbus::Result<String>;

    /// PartitionInfo property
    #[dbus_proxy(property)]
    fn partition_info(&self) -> zbus::Result<String>;

    /// Status property
    #[dbus_proxy(property)]
    fn status(&self) -> zbus::Result<String>;

    /// Type property
    #[dbus_proxy(property)]
    fn type_(&self) -> zbus::Result<String>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.ZFCP.Manager",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait ZFCPManager {
    /// Probe method
    fn probe(&self) -> zbus::Result<()>;

    /// AllowLUNScan property
    #[dbus_proxy(property, name = "AllowLUNScan")]
    fn allow_lunscan(&self) -> zbus::Result<bool>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.ZFCP.Controller",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait ZFCPController {
    /// Activate method
    fn activate(&self) -> zbus::Result<u32>;

    /// ActivateDisk method
    fn activate_disk(&self, wwpn: &str, lun: &str) -> zbus::Result<u32>;

    /// DeactivateDisk method
    fn deactivate_disk(&self, wwpn: &str, lun: &str) -> zbus::Result<u32>;

    /// GetLUNs method
    #[dbus_proxy(name = "GetLUNs")]
    fn get_luns(&self, wwpn: &str) -> zbus::Result<Vec<String>>;

    /// GetWWPNs method
    #[dbus_proxy(name = "GetWWPNs")]
    fn get_wwpns(&self) -> zbus::Result<Vec<String>>;

    /// Active property
    #[dbus_proxy(property)]
    fn active(&self) -> zbus::Result<bool>;

    /// Channel property
    #[dbus_proxy(property)]
    fn channel(&self) -> zbus::Result<String>;

    /// LUNScan property
    #[dbus_proxy(property, name = "LUNScan")]
    fn lunscan(&self) -> zbus::Result<bool>;
}

#[dbus_proxy(
    interface = "org.opensuse.Agama.Storage1.ZFCP.Disk",
    default_service = "org.opensuse.Agama.Storage1",
    default_path = "/org/opensuse/Agama/Storage1"
)]
trait Disk {
    /// Channel property
    #[dbus_proxy(property)]
    fn channel(&self) -> zbus::Result<String>;

    /// LUN property
    #[dbus_proxy(property, name = "LUN")]
    fn lun(&self) -> zbus::Result<String>;

    /// Name property
    #[dbus_proxy(property)]
    fn name(&self) -> zbus::Result<String>;

    /// WWPN property
    #[dbus_proxy(property, name = "WWPN")]
    fn wwpn(&self) -> zbus::Result<String>;
}
