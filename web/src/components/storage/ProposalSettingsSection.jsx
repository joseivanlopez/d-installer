/*
 * Copyright (c) [2022-2024] SUSE LLC
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

import React, { useEffect, useState } from "react";
import { Button, Checkbox, Form, Skeleton, Switch, Tooltip } from "@patternfly/react-core";

import { sprintf } from "sprintf-js";
import { _ } from "~/i18n";
import { BootSelectionDialog, ProposalVolumes, ProposalSpacePolicyField } from "~/components/storage";
import { If, PasswordAndConfirmationInput, Section, Popup } from "~/components/core";
import { Icon } from "~/components/layout";
import { noop } from "~/utils";
import { hasFS, deviceLabel } from "~/components/storage/utils";

/**
 * @typedef {import ("~/client/storage").ProposalManager.ProposalSettings} ProposalSettings
 * @typedef {import ("~/client/storage").DevicesManager.StorageDevice} StorageDevice
 * @typedef {import ("~/client/storage").ProposalManager.Volume} Volume
 */

/**
 * Form for configuring the encryption password.
 * @component
 *
 * @param {object} props
 * @param {string} props.id - Form ID.
 * @param {string} props.password - Password for encryption.
 * @param {onSubmitFn} [props.onSubmit=noop] - On submit callback.
 * @param {onValidateFn} [props.onValidate=noop] - On validate callback.
 *
 * @callback onSubmitFn
 * @param {string} password
 *
 * @callback onValidateFn
 * @param {boolean} valid
 */
const EncryptionSettingsForm = ({
  id,
  password: passwordProp,
  method: methodProp,
  methods,
  onSubmit = noop,
  onValidate = noop
}) => {
  const [password, setPassword] = useState(passwordProp || "");
  const [method, setMethod] = useState(methodProp);
  const tpmId = "tpm_fde";
  const luks2Id = "luks2";

  useEffect(() => {
    if (password.length === 0) onValidate(false);
  }, [password, onValidate]);

  const changePassword = (_, v) => setPassword(v);

  const changeMethod = (_, value) => {
    value ? setMethod(tpmId) : setMethod(luks2Id);
  };

  const submitForm = (e) => {
    e.preventDefault();
    onSubmit(password, method);
  };

  const Description = () => (
    <span
      dangerouslySetInnerHTML={{
        // TRANSLATORS: The word 'directly' is key here. For example, booting to the installer media and then choosing
        // 'Boot from Hard Disk' from there will not work. Keep it sort (this is a hint in a form) but keep it clear.
        // Do not translate 'abbr' and 'title', they are part of the HTML markup.
        __html: _("The password will not be needed to boot and access the data if the <abbr title='Trusted Platform Module'>TPM</abbr> can verify the integrity of the system. TPM sealing requires the new system to be booted directly on its first run.")
      }}
    />
  );

  return (
    <Form id={id} onSubmit={submitForm}>
      <PasswordAndConfirmationInput
        id="encryptionPasswordInput"
        value={password}
        onChange={changePassword}
        onValidation={onValidate}
      />
      <If
        condition={methods.includes(tpmId)}
        then={
          <Checkbox
            id="encryption_method"
            label={_("Use the TPM to decrypt automatically on each boot")}
            description={<Description />}
            isChecked={method === tpmId}
            onChange={changeMethod}
          />
        }
      />
    </Form>
  );
};

/**
 * Allows to define snapshots enablement
 * @component
 *
 * @param {object} props
 * @param {ProposalSettings} props.settings - Settings used for calculating a proposal.
 * @param {onChangeFn} [props.onChange=noop] - On change callback
 *
 * @callback onChangeFn
 * @param {object} settings
 */
const SnapshotsField = ({
  settings,
  onChange = noop
}) => {
  const rootVolume = (settings.volumes || []).find((i) => i.mountPath === "/");

  // no root volume is probably some error or still loading
  if (rootVolume === undefined) {
    return <Skeleton width="25%" />;
  }

  const isChecked = rootVolume !== undefined && hasFS(rootVolume, "Btrfs") && rootVolume.snapshots;

  const switchState = (_, checked) => {
    onChange({ active: checked, settings });
  };

  if (!rootVolume.outline.snapshotsConfigurable) return;

  const explanation = _("Uses Btrfs for the root file system allowing to boot to a previous \
version of the system after configuration changes or software upgrades.");

  return (
    <div>
      <Switch
        id="snapshots"
        label={_("Use Btrfs Snapshots")}
        isReversed
        isChecked={isChecked}
        onChange={switchState}
      />
      <div>
        {explanation}
      </div>
    </div>
  );
};

/**
 * Allows to define encryption
 * @component
 *
 * @param {object} props
 * @param {string} [props.password=""] - Password for encryption
 * @param {string} [props.method=""] - Encryption method
 * @param {boolean} [props.isChecked=false] - Whether encryption is selected
 * @param {boolean} [props.isLoading=false] - Whether to show the selector as loading
 * @param {onChangeFn} [props.onChange=noop] - On change callback
 *
 * @callback onChangeFn
 * @param {object} settings
 */
const EncryptionField = ({
  password: passwordProp = "",
  method: methodProp = "",
  methods,
  isChecked: isCheckedProp = false,
  isLoading = false,
  onChange = noop
}) => {
  const [isChecked, setIsChecked] = useState(isCheckedProp);
  const [password, setPassword] = useState(passwordProp);
  const [method, setMethod] = useState(methodProp);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isFormValid, setIsFormValid] = useState(true);

  const openForm = () => setIsFormOpen(true);

  const closeForm = () => setIsFormOpen(false);

  const acceptForm = (newPassword, newMethod) => {
    closeForm();
    setPassword(newPassword);
    setMethod(newMethod);
    onChange({ isChecked, password: newPassword, method: newMethod });
  };

  const cancelForm = () => {
    closeForm();
    if (password.length === 0) setIsChecked(false);
  };

  const validateForm = (valid) => setIsFormValid(valid);

  const changeSelected = (_, value) => {
    setIsChecked(value);

    if (value && password.length === 0) openForm();

    if (!value) {
      setPassword("");
      onChange({ isChecked: false, password: "" });
    }
  };

  const ChangeSettingsButton = () => {
    return (
      <Tooltip
        content={_("Change encryption settings")}
        entryDelay={400}
        exitDelay={50}
        position="right"
      >
        <button aria-label={_("Encryption settings")} className="plain-control" onClick={openForm}>
          <Icon name="tune" size="s" />
        </button>
      </Tooltip>
    );
  };

  if (isLoading) return <Skeleton width="25%" />;

  return (
    <>
      <div className="split">
        <Switch
          id="encryption"
          label={_("Use encryption")}
          isReversed
          isChecked={isChecked}
          onChange={changeSelected}
        />
        { isChecked && <ChangeSettingsButton /> }
      </div>
      <Popup aria-label={_("Encryption settings")} title={_("Encryption settings")} isOpen={isFormOpen}>
        <EncryptionSettingsForm
          id="encryptionSettingsForm"
          password={password}
          method={method}
          methods={methods}
          onSubmit={acceptForm}
          onValidate={validateForm}
        />
        <Popup.Actions>
          <Popup.Confirm form="encryptionSettingsForm" type="submit" isDisabled={!isFormValid}>{_("Accept")}</Popup.Confirm>
          <Popup.Cancel onClick={cancelForm} />
        </Popup.Actions>
      </Popup>
    </>
  );
};

/**
 * Allows to select the boot config.
 * @component
 *
 * @param {object} props
 * @param {boolean} props.configureBoot
 * @param {StorageDevice} props.bootDevice
 * @param {StorageDevice[]} props.devices
 * @param {boolean} props.isLoading
 * @param {(boot: Boot) => void} props.onChange
 *
 * @typedef {object} Boot
 * @property {boolean} configureBoot
 * @property {StorageDevice} bootDevice
 */
const BootConfigField = ({
  configureBoot,
  bootDevice,
  devices,
  isLoading,
  onChange
}) => {
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  const openDialog = () => setIsDialogOpen(true);

  const closeDialog = () => setIsDialogOpen(false);

  const onAccept = ({ configureBoot, bootDevice }) => {
    closeDialog();
    onChange({ configureBoot, bootDevice });
  };

  const label = _("Automatically configure any additional partition to boot the system");

  const value = () => {
    if (!configureBoot) return _("nowhere (manual boot setup)");

    if (!bootDevice) return _("at the installation device");

    // TRANSLATORS: %s is the disk used to configure the boot-related partitions (eg. "/dev/sda, 80 GiB)
    return sprintf(_("at %s"), deviceLabel(bootDevice));
  };

  if (isLoading) {
    return <Skeleton screenreaderText={_("Waiting for information about boot config")} width="25%" />;
  }

  return (
    <div className="split">
      <span>{label}</span>
      <Button variant="link" isInline onClick={openDialog}>{value()}</Button>
      <If
        condition={isDialogOpen}
        then={
          <BootSelectionDialog
            isOpen
            configureBoot={configureBoot}
            bootDevice={bootDevice}
            devices={devices}
            onAccept={onAccept}
            onCancel={closeDialog}
          />
        }
      />
    </div>
  );
};

/**
 * Section for editing the proposal settings
 * @component
 *
 * @param {object} props
 * @param {ProposalSettings} props.settings
 * @param {StorageDevice[]} [props.availableDevices=[]]
 * @param {String[]} [props.encryptionMethods=[]]
 * @param {onChangeFn} [props.onChange=noop]
 *
 * @callback onChangeFn
 * @param {object} settings
 */
export default function ProposalSettingsSection({
  settings,
  availableDevices = [],
  encryptionMethods = [],
  volumeTemplates = [],
  isLoading = false,
  onChange = noop
}) {
  const changeEncryption = ({ password, method }) => {
    onChange({ encryptionPassword: password, encryptionMethod: method });
  };

  const changeBtrfsSnapshots = ({ active, settings }) => {
    const rootVolume = settings.volumes.find((i) => i.mountPath === "/");

    if (active) {
      rootVolume.fsType = "Btrfs";
      rootVolume.snapshots = true;
    } else {
      rootVolume.snapshots = false;
    }

    onChange({ volumes: settings.volumes });
  };

  const changeVolumes = (volumes) => {
    onChange({ volumes });
  };

  const changeSpacePolicy = (policy, actions) => {
    onChange({ spacePolicy: policy, spaceActions: actions });
  };

  const changeBoot = ({ configureBoot, bootDevice }) => {
    onChange({
      configureBoot,
      bootDevice: bootDevice?.name
    });
  };

  const encryption = settings.encryptionPassword !== undefined && settings.encryptionPassword.length > 0;

  const { volumes = [], installationDevices = [] } = settings;

  const bootDevice = availableDevices.find(d => d.name === settings.bootDevice);

  // Templates for already existing mount points are filtered out
  const usefulTemplates = () => {
    const mountPaths = volumes.map(v => v.mountPath);
    return volumeTemplates.filter(t => (
      t.mountPath.length > 0 && !mountPaths.includes(t.mountPath)
    ));
  };

  return (
    <>
      <Section title={_("Settings")}>
        <SnapshotsField
          settings={settings}
          onChange={changeBtrfsSnapshots}
        />
        <EncryptionField
          password={settings.encryptionPassword || ""}
          method={settings.encryptionMethod}
          methods={encryptionMethods}
          isChecked={encryption}
          isLoading={settings.encryptionPassword === undefined}
          onChange={changeEncryption}
        />
        <ProposalVolumes
          volumes={volumes}
          templates={usefulTemplates()}
          options={{ lvm: settings.lvm, encryption }}
          isLoading={isLoading && settings.volumes === undefined}
          onChange={changeVolumes}
        />
        <BootConfigField
          configureBoot={settings.configureBoot}
          bootDevice={bootDevice}
          devices={availableDevices}
          isLoading={isLoading}
          onChange={changeBoot}
        />
        <ProposalSpacePolicyField
          policy={settings.spacePolicy}
          actions={settings.spaceActions}
          devices={installationDevices}
          isLoading={isLoading}
          onChange={changeSpacePolicy}
        />
      </Section>
    </>
  );
}
