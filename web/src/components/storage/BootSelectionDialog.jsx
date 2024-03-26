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

import React, { useState } from "react";
import { Form } from "@patternfly/react-core";

import { _ } from "~/i18n";
import { deviceChildren } from "~/components/storage/utils";
import { ControlledPanels as Panels, Popup } from "~/components/core";
import { DeviceSelectorTable } from "~/components/storage";
import { noop } from "~/utils";

/**
 * @typedef {import ("~/client/storage").StorageDevice} StorageDevice
 */

const BOOT_AUTO_ID = "boot-auto";
const BOOT_MANUAL_ID = "boot-manual";
const BOOT_DISABLED_ID = "boot-disabled";
const BOOT_AUTO_PANEL_ID = "panel-for-boot-auto";
const BOOT_MANUAL_PANEL_ID = "panel-for-boot-manual";
const BOOT_DISABLED_PANEL_ID = "panel-for-boot-disabled";
const OPTIONS_NAME = "boot-mode";

/**
 * Renders a dialog that allows the user to select the boot configuration.
 * @component
 *
 * @param {object} props
 * @param {boolean} props.configureBoot
 * @param {StorageDevice|undefined} props.bootDevice
 * @param {StorageDevice[]} props.devices - The actions to perform in the system.
 * @param {boolean} [props.isOpen=false] - Whether the dialog is visible or not.
 * @param {function} [props.onCancel=noop] - Callback to execute when user closes the dialog.
 * @param {(boot: Boot) => void} props.onAccept
 *
 * @typedef {object} Boot
 * @property {boolean} configureBoot
 * @property {StorageDevice|undefined} bootDevice

 */
export default function BootSelectionDialog({
  configureBoot: defaultConfigureBoot,
  bootDevice: defaultBootDevice,
  devices,
  isOpen,
  onCancel = noop,
  onAccept = noop,
  ...props
}) {
  const [configureBoot, setConfigureBoot] = useState(defaultConfigureBoot);
  const [bootDevice, setBootDevice] = useState(defaultBootDevice);
  const [isBootAuto, setIsBootAuto] = useState(defaultConfigureBoot && defaultBootDevice === undefined);

  const isBootManual = configureBoot && !isBootAuto;
  const isBootDisabled = !configureBoot;

  const selectBootAuto = () => {
    setConfigureBoot(true);
    setIsBootAuto(true);
  };

  const selectBootManual = () => {
    setConfigureBoot(true);
    setIsBootAuto(false);
  };

  const selectBootDisabled = () => {
    setConfigureBoot(false);
    setIsBootAuto(false);
  };

  const selectBootDevice = (devices) => setBootDevice(devices[0]);

  const onSubmit = (e) => {
    e.preventDefault();
    const device = isBootAuto ? undefined : bootDevice;
    onAccept({ configureBoot, bootDevice: device });
  };

  const isAcceptDisabled = () => {
    return isBootManual && bootDevice === undefined;
  };

  const isDeviceSelectable = (device) => device.isDrive || device.type === "md";

  return (
    <Popup
      title={_("Configuration for boot partitions")}
      isOpen={isOpen}
      variant="medium"
      {...props}
    >
      <Form id="boot-form" onSubmit={onSubmit}>
        <Panels className="stack">
          <Panels.Options data-variant="buttons">
            <Panels.Option
              id={BOOT_AUTO_ID}
              name={OPTIONS_NAME}
              isSelected={isBootAuto}
              onChange={selectBootAuto}
              controls={BOOT_AUTO_PANEL_ID}
            >
              {_("Automatic")}
            </Panels.Option>
            <Panels.Option
              id={BOOT_MANUAL_ID}
              name={OPTIONS_NAME}
              isSelected={isBootManual}
              onChange={selectBootManual}
              controls={BOOT_MANUAL_PANEL_ID}
            >
              {_("Select a disk")}
            </Panels.Option>
            <Panels.Option
              id={BOOT_DISABLED_ID}
              name={OPTIONS_NAME}
              isSelected={isBootDisabled}
              onChange={selectBootDisabled}
              controls={BOOT_DISABLED_PANEL_ID}
            >
              {_("Do not configure")}
            </Panels.Option>
          </Panels.Options>
          <Panels.Panel id={BOOT_AUTO_PANEL_ID} isExpanded={isBootAuto}>
            <p>
              {_("If needed, additional partitions to boot the system will be configured in the \
device selected for installing the system.")}
            </p>
          </Panels.Panel>

          <Panels.Panel id={BOOT_MANUAL_PANEL_ID} isExpanded={isBootManual}>
            <p>
              {_("If needed, additional partitions to boot the system will be configured in the \
following selected device.")}
            </p>

            <DeviceSelectorTable
              devices={devices}
              selected={[bootDevice]}
              itemChildren={deviceChildren}
              itemSelectable={isDeviceSelectable}
              onSelectionChange={selectBootDevice}
              variant="compact"
            />
          </Panels.Panel>
          <Panels.Panel id={BOOT_DISABLED_PANEL_ID} isExpanded={isBootDisabled}>
            <p>
              {_("Additional partitions will not be configured to boot the system.")}
            </p>
          </Panels.Panel>
        </Panels>
      </Form>
      <Popup.Actions>
        <Popup.Confirm form="boot-form" type="submit" isDisabled={isAcceptDisabled()} />
        <Popup.Cancel onClick={onCancel} />
      </Popup.Actions>
    </Popup>
  );
}
