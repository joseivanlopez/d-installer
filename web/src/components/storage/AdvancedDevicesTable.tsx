/*
 * Copyright (c) [2024] SUSE LLC
 *
 * All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
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

import React, { useRef, useState } from "react";
import { Label, Flex } from "@patternfly/react-core";
import {
  DeviceName,
  DeviceDetails,
  DeviceSize,
  toStorageDevice,
} from "~/components/storage/device-utils";
import DevicesManager from "~/components/storage/DevicesManager";
import { Drawer, TreeTable } from "~/components/core";
import { _ } from "~/i18n";
import { sprintf } from "sprintf-js";
import { deviceChildren, deviceSize } from "~/components/storage/utils";
import { PartitionSlot, StorageDevice } from "~/types/storage";
import { TreeTableColumn } from "~/components/core/TreeTable";
import { ActionsColumn } from "@patternfly/react-table";
import { Toolbar, ToolbarItem, ToolbarContent } from "@patternfly/react-core";
import { Button, SearchInput } from "@patternfly/react-core";
import {
  useConfigMutation,
  useIncrementalConfigMutation,
  useProposalResult,
} from "~/queries/storage";
import OpenDrawerRightIcon from "@patternfly/react-icons/dist/esm/icons/open-drawer-right-icon";
import { ProposalActionsDialog } from "~/components/storage";
import AddPartitionDialog from "./AddPartitionDialog";

type TableItem = StorageDevice | PartitionSlot;

/**
 * @component
 */
const MountPoint = ({ item }: { item: TableItem }) => {
  const device = toStorageDevice(item);

  if (!(device && device.filesystem?.mountPath)) return null;

  return <em>{device.filesystem.mountPath}</em>;
};

/**
 * @component
 */
const DeviceCustomDetails = ({
  item,
  devicesManager,
}: {
  item: TableItem;
  devicesManager: DevicesManager;
}) => {
  const isNew = () => {
    const device = toStorageDevice(item);
    if (!device) return false;

    // FIXME New PVs over a disk is not detected as new.
    return !devicesManager.existInSystem(device) || devicesManager.hasNewFilesystem(device);
  };

  return (
    <Flex direction={{ default: "row" }} gap={{ default: "gapXs" }}>
      <DeviceDetails item={item} />
      {isNew() && (
        <Label color="green" isCompact>
          {_("New")}
        </Label>
      )}
    </Flex>
  );
};

/**
 * @component
 */
const DeviceCustomSize = ({
  item,
  devicesManager,
}: {
  item: TableItem;
  devicesManager: DevicesManager;
}) => {
  const device = toStorageDevice(item);
  const isResized = device && devicesManager.isShrunk(device);
  const sizeBefore = isResized ? devicesManager.systemDevice(device.sid).size : item.size;

  return (
    <Flex direction={{ default: "row" }} gap={{ default: "gapXs" }}>
      <DeviceSize item={item} />
      {isResized && (
        <Label color="orange" isCompact>
          {
            // TRANSLATORS: Label to indicate the device size before resizing, where %s is
            // replaced by the original size (e.g., 3.00 GiB).
            sprintf(_("Before %s"), deviceSize(sizeBefore))
          }
        </Label>
      )}
    </Flex>
  );
};

function installConfig(device: StorageDevice) {
  return {
    storage: {
      drives: [
        {
          search: device.name,
          partitions: [{ generate: "default" }],
        },
      ],
    },
  };
}

function deleteAllPartitionsConfig(device: StorageDevice) {
  return {
    storage: {
      boot: {
        configure: false,
      },
      drives: [
        {
          search: device.name,
          partitions: [
            {
              search: "*",
              delete: true,
            },
          ],
        },
      ],
    },
  };
}

function deletePartitionConfig(parent: StorageDevice, device: StorageDevice) {
  return {
    storage: {
      boot: {
        configure: false,
      },
      drives: [
        {
          search: parent.name,
          partitions: [{ search: device.name, delete: true }],
        },
      ],
    },
  };
}

function addBootPartitionConfig(device: StorageDevice) {
  return {
    storage: {
      boot: {
        configure: true,
        device: device.name,
      },
    },
  };
}

function addHomePartitionConfig(device: StorageDevice) {
  return {
    storage: {
      boot: { configure: false },
      drives: [
        {
          search: device.name,
          partitions: [{ filesystem: { path: "/home" } }],
        },
      ],
    },
  };
}

function addSwapPartitionConfig(device: StorageDevice) {
  return {
    storage: {
      boot: { configure: false },
      drives: [
        {
          search: device.name,
          partitions: [{ filesystem: { path: "swap" } }],
        },
      ],
    },
  };
}

const DiskActions = ({ device, action }: { device: StorageDevice; action }) => {
  const setConfig = useIncrementalConfigMutation();

  const actions = [
    {
      title: "Use as installation device",
      onClick: () => setConfig.mutate(installConfig(device)),
    },
    {
      isSeparator: true,
    },
    {
      title: "Add boot partition",
      onClick: () => setConfig.mutate(addBootPartitionConfig(device)),
    },
    {
      title: "Add separate /home",
      onClick: () => setConfig.mutate(addHomePartitionConfig(device)),
    },
    {
      title: "Add separate swap",
      onClick: () => setConfig.mutate(addSwapPartitionConfig(device)),
    },
    {
      isSeparator: true,
    },
    {
      title: "Add custom partition",
      onClick: () => action(device),
    },
    {
      isSeparator: true,
    },
    {
      title: "Delete all partition",
      onClick: () => setConfig.mutate(deleteAllPartitionsConfig(device)),
    },
  ];

  return <ActionsColumn items={actions} />;
};

const PartitionActions = ({
  device,
  devicesManager,
}: {
  device: StorageDevice;
  devicesManager: DevicesManager;
}) => {
  const setConfig = useIncrementalConfigMutation();
  const parent = devicesManager.parentInStaging(device);

  const actions = [
    {
      title: "Delete",
      onClick: () => setConfig.mutate(deletePartitionConfig(parent, device)),
    },
  ];

  return <ActionsColumn items={actions} />;
};

const DeviceActions = ({
  item,
  devicesManager,
  action,
}: {
  item: TableItem;
  devicesManager: DevicesManager;
  action;
}) => {
  const device = toStorageDevice(item);
  if (!device) return;

  if (device.type === "disk") return <DiskActions device={device} action={action} />;
  if (device.type === "partition")
    return <PartitionActions device={device} devicesManager={devicesManager} />;
};

function columns(devicesManager: DevicesManager, action): TreeTableColumn[] {
  const renderDevice: (item: TableItem) => React.ReactNode = (item): React.ReactNode => (
    <DeviceName item={item} />
  );

  const renderMountPoint: (item: TableItem) => React.ReactNode = (item) => (
    <MountPoint item={item} />
  );

  const renderDetails: (item: TableItem) => React.ReactNode = (item) => (
    <DeviceCustomDetails item={item} devicesManager={devicesManager} />
  );

  const renderSize: (item: TableItem) => React.ReactNode = (item) => (
    <DeviceCustomSize item={item} devicesManager={devicesManager} />
  );

  const renderActions: (item: TableItem) => React.ReactNode = (item) => (
    <DeviceActions item={item} devicesManager={devicesManager} action={action} />
  );

  return [
    { name: _("Device"), value: renderDevice },
    { name: _("Mount Point"), value: renderMountPoint },
    { name: _("Details"), value: renderDetails },
    { name: _("Size"), value: renderSize, classNames: "sizes-column" },
    { name: undefined, value: renderActions },
  ];
}

type ProposalResultTableProps = {
  devicesManager: DevicesManager;
};

/**
 * Renders the proposal result.
 * @component
 */
export default function AdvancedDevicesTable({ devicesManager }: ProposalResultTableProps) {
  const drawerRef = useRef();
  const { actions } = useProposalResult();
  const setConfig = useConfigMutation();
  const setIncrementalConfig = useIncrementalConfigMutation();
  const [isAddPartitionOpen, setIsAddPartitionOpen] = useState(false);
  const [device, setDevice] = useState();

  // const devices = devicesManager.usedDevices();
  const devices = devicesManager.stagingDevices();

  const reset = () => {
    const config = {
      storage: {
        boot: {
          configure: false,
        },
      },
    };

    setConfig.mutate(config);
  };

  const addPartition = (config) => {
    setIncrementalConfig.mutate(config);
    setIsAddPartitionOpen(false);
  };

  const action = (device) => {
    setDevice(device);
    setIsAddPartitionOpen(true);
  };

  return (
    <>
      <Drawer
        ref={drawerRef}
        panelHeader={<h4>{_("Planned Actions")}</h4>}
        panelContent={<ProposalActionsDialog actions={actions} />}
      >
        <Flex justifyContent={{ default: "justifyContentSpaceBetween" }}>
          <Toolbar id="toolbar-items-example" style={{ marginBlockEnd: "18px" }}>
            <ToolbarContent>
              <ToolbarItem>
                <SearchInput aria-label={_("Items example search input")} />
              </ToolbarItem>
              <ToolbarItem>
                <Button variant="secondary">{_("Add LVM")}</Button>
              </ToolbarItem>
              <ToolbarItem>
                <Button variant="secondary">{_("Add RAID")}</Button>
              </ToolbarItem>
              <ToolbarItem variant="separator" />
              <ToolbarItem>
                <Button variant="secondary" isDanger onClick={reset}>
                  {_("Reset")}
                </Button>
              </ToolbarItem>
            </ToolbarContent>
          </Toolbar>
          <Button
            isDisabled={!actions.length}
            variant="secondary"
            icon={<OpenDrawerRightIcon />}
            iconPosition="end"
            onClick={drawerRef.current?.open}
          >
            {_("Actions")}
          </Button>
        </Flex>
        <TreeTable
          columns={columns(devicesManager, action)}
          items={devices}
          expandedItems={devices}
          itemChildren={deviceChildren}
          rowClassNames={(item) => {
            if (!item.sid) return "dimmed-row";
          }}
          className="proposal-result"
        />
      </Drawer>
      {isAddPartitionOpen && (
        <AddPartitionDialog
          isOpen
          device={device}
          onAccept={addPartition}
          onCancel={() => setIsAddPartitionOpen(false)}
        />
      )}
    </>
  );
}