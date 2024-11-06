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

//! # D-Bus interface proxy for: `org.opensuse.Agama.Software1.Product`
//!
//! This code was generated by `zbus-xmlgen` `5.0.0` from D-Bus introspection data.
//! Source: `org.opensuse.Agama.Software1.Product.bus.xml`.
//!
//! You may prefer to adapt it, instead of using it verbatim.
//!
//! More information can be found in the [Writing a client proxy] section of the zbus
//! documentation.
//!
//! This type implements the [D-Bus standard interfaces], (`org.freedesktop.DBus.*`) for which the
//! following zbus API can be used:
//!
//! * [`zbus::fdo::PropertiesProxy`]
//! * [`zbus::fdo::IntrospectableProxy`]
//!
//! Consequently `zbus-xmlgen` did not generate code for the above interfaces.
//!
//! [Writing a client proxy]: https://dbus2.github.io/zbus/client.html
//! [D-Bus standard interfaces]: https://dbus.freedesktop.org/doc/dbus-specification.html#standard-interfaces,
use zbus::proxy;

/// Product definition.
///
/// It is composed of the following elements:
///
/// * Product ID.
/// * Display name.
/// * Some additional data which includes a "description" key.
pub type Product = (
    String,
    String,
    std::collections::HashMap<String, zbus::zvariant::OwnedValue>,
);

#[proxy(
    default_service = "org.opensuse.Agama.Software1",
    default_path = "/org/opensuse/Agama/Software1/Product",
    interface = "org.opensuse.Agama.Software1.Product",
    assume_defaults = true
)]
pub trait Product {
    /// AvailableProducts method
    fn available_products(&self) -> zbus::Result<Vec<Product>>;

    /// SelectProduct method
    fn select_product(&self, id: &str) -> zbus::Result<(u32, String)>;

    /// SelectedProduct property
    #[zbus(property)]
    fn selected_product(&self) -> zbus::Result<String>;
}
