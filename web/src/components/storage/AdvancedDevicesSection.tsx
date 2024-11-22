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

import React from "react";
import { Skeleton, Stack } from "@patternfly/react-core";
import { Page } from "~/components/core";
import DevicesManager from "~/components/storage/DevicesManager";
import AdvancedDevicesTable from "~/components/storage/AdvancedDevicesTable";
import { _ } from "~/i18n";
import { Action, StorageDevice } from "~/types/storage";
import { ValidationError } from "~/types/issues";
import { Alert } from "@patternfly/react-core";

/**
 * @todo Create a component for rendering a customized skeleton
 */
const ResultSkeleton = () => (
  <Stack hasGutter>
    <Skeleton
      screenreaderText={_("Waiting for information about storage configuration")}
      width="80%"
    />
    <Skeleton width="65%" />
    <Skeleton width="70%" />
  </Stack>
);

export type ProposalResultSectionProps = {
  system?: StorageDevice[];
  staging?: StorageDevice[];
  actions?: Action[];
  errors?: ValidationError[];
  isLoading?: boolean;
};

export default function ProposalResultSection({
  system = [],
  staging = [],
  actions = [],
  errors = [],
  isLoading = false,
}: ProposalResultSectionProps) {
  return (
    <Page.Section aria-label={_("The systems will be configured as displayed below.")}>
      {isLoading && <ResultSkeleton />}
      {errors.length > 0 && (
        <Alert
          variant="danger"
          title={_("The requested action cannot be done")}
          ouiaId="DangerAlert"
          style={{ marginBlockEnd: "14px" }}
        />
      )}
      <AdvancedDevicesTable devicesManager={new DevicesManager(system, staging, actions)} />
    </Page.Section>
  );
}