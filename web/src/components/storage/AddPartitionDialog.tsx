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

import React, { FormEvent, useState } from "react";
import { Form, FormGroup, FormSelect, FormSelectOption, TextInput } from "@patternfly/react-core";
import { Popup } from "~/components/core";
import { _ } from "~/i18n";
import { StorageDevice } from "~/types/storage";

const MountPath = ({ value, onChange }) => {
  const change = (_, v) => onChange(v);
  return <TextInput value={value} onChange={change} aria-label={_("Mount path")} />;
};

const FsSelect = ({ value, onChange }) => {
  const options = [
    { value: "btrfs", label: "Btrfs" },
    { value: "xfs", label: "XFS" },
    { value: "ext4", label: "EXT4" },
    { value: "swap", label: "Swap" },
  ];

  const change = (_, v) => onChange(v);

  return (
    <FormSelect value={value} onChange={change} aria-label={_("File system")}>
      {options.map((option, index) => (
        <FormSelectOption key={index} value={option.value} label={option.label} />
      ))}
    </FormSelect>
  );
};

const Size = ({ value, onChange }) => {
  const change = (_, v) => onChange(v);
  return <TextInput value={value} onChange={change} aria-label={_("Size")} />;
};

export type AddPartitionDialogProps = {
  device: StorageDevice;
  isOpen?: boolean;
  onCancel: () => void;
  onAccept: (config) => void;
};

/**
 * Renders a dialog that allows the user to add or edit a file system.
 * @component
 */
export default function AddPartitionDialog({
  device,
  isOpen,
  onCancel,
  onAccept,
}: AddPartitionDialogProps) {
  const [path, setPath] = useState("");
  const [fs, setFs] = useState("btrfs");
  const [size, setSize] = useState("1 GiB");

  const submitForm: (e: FormEvent) => void = (e) => {
    e.preventDefault();

    const config = {
      storage: {
        drives: [
          {
            search: device.name,
            partitions: [{ filesystem: { path, type: fs }, size }],
          },
        ],
      },
    };

    onAccept(config);
  };

  return (
    /** @fixme blockSize medium is too big and small is too small. */
    <Popup title={_("Add custom partition")} isOpen={isOpen} blockSize="medium" inlineSize="medium">
      <Form id="add-partition-form" onSubmit={submitForm}>
        <FormGroup label={_("Mount path")} fieldId="mountPath">
          <MountPath value={path} onChange={setPath} />
        </FormGroup>
        <FormGroup label={_("File system")} fieldId="fsType">
          <FsSelect value={fs} onChange={setFs} />
        </FormGroup>
        <FormGroup label={_("Size")} fieldId="size">
          <Size value={size} onChange={setSize} />
        </FormGroup>
      </Form>
      <Popup.Actions>
        <Popup.Confirm form="add-partition-form" type="submit">
          {_("Accept")}
        </Popup.Confirm>
        <Popup.Cancel onClick={onCancel} />
      </Popup.Actions>
    </Popup>
  );
}
