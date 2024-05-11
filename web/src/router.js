/*
 * Copyright (c) [2024] SUSE LLC
 *
 * All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of version 2 of the GNU General Public License as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, contact SUSE LLC.
 *
 * To contact SUSE LLC about this file by physical or electronic mail, you may
 * find current contact information at www.suse.com.
 */

import React from "react";
import { createHashRouter } from "react-router-dom";
import App from "~/App";
import Main from "~/Main";
import { OverviewPage } from "~/components/overview";
import { ProductPage, ProductSelectionPage } from "~/components/product";
import { SoftwarePage } from "~/components/software";
import { ProposalPage as StoragePage, ISCSIPage, DASDPage, ZFCPPage } from "~/components/storage";
import { UsersPage } from "~/components/users";
import { L10nPage } from "~/components/l10n";
import { NetworkPage } from "~/components/network";
import { _ } from "~/i18n";

// FIXME: think in a better apprach for routes, if any.
// FIXME: think if it worth it to have the routes ready for work with them
// dinamically of would be better to go for an explicit use of them (see
// Root#Sidebar navigation)

const createRoute = (name, path, element, children = [], icon) => (
  {
    path,
    element,
    handle: { name, icon },
    children
  }
);

const overviewRoutes = createRoute(_("Overview"), "overview", <OverviewPage />, [], "list_alt");
const productRoutes = createRoute(_("Product"), "product", <ProductPage />, [], "inventory_2");
const l10nRoutes = createRoute(_("Localization"), "l10n", <L10nPage />, [], "globe");
const softwareRoutes = createRoute(_("Software"), "software", <SoftwarePage />, [], "apps");
const storageRoutes = createRoute(_("Storage"), "storage", <StoragePage />, [
  createRoute(_("iSCSI"), "iscsi", <ISCSIPage />),
  createRoute(_("DASD"), "dasd", <DASDPage />),
  createRoute(_("ZFCP"), "zfcp", <ZFCPPage />)
], "hard_drive");
const networkRoutes = createRoute(_("Network"), "network", <NetworkPage />, [], "settings_ethernet");
const usersRoutes = createRoute(_("Users"), "users", <UsersPage />, [], "manage_accounts");

const rootRoutes = [
  overviewRoutes,
  productRoutes,
  l10nRoutes,
  softwareRoutes,
  storageRoutes,
  networkRoutes,
  usersRoutes,
];

const routes = [
  {
    path: "/",
    element: <App />,
    children: [
      {
        element: <Main />,
        children: [
          {
            index: true,
            element: <OverviewPage />
          },
          ...rootRoutes
        ]
      },
      {
        path: "products",
        element: <ProductSelectionPage />
      }
    ]
  }
];

const router = createHashRouter(routes);

export {
  overviewRoutes,
  productRoutes,
  l10nRoutes,
  softwareRoutes,
  storageRoutes,
  networkRoutes,
  usersRoutes,
  rootRoutes,
  routes,
  router
};