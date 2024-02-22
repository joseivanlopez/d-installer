# frozen_string_literal: true

# Copyright (c) [2022-2024] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "agama/storage/lvm_settings"
require "agama/storage/encryption_settings"
require "agama/storage/space_settings"

module Agama
  module Storage
    # Settings used to calculate an storage proposal.
    class ProposalSettings
      # Configuration of LVM
      #
      # @return [LvmSettings]
      attr_reader :lvm

      # Encryption settings
      #
      # @return [EncryptionSettings]
      attr_reader :encryption

      # Settings to configure the behavior when making space to allocate the new partitions
      #
      # @return [SpaceSettings]
      attr_reader :space

      # Device name of the device that will be used by default to allocate all the partitions. This
      # is the default location for everything (i.e., boot partitions, LVM  PVs and volumes
      # location) if nothing else is indicated.
      #
      # @return [String, nil] nil if no device has been selected yet.
      attr_accessor :default_device

      # Device name of the device that will be used to allocate the partitions required for booting.
      # If no device is indicated, then the {#default_device} will be used.
      #
      # @return [String, nil]
      attr_accessor :boot_device

      # Whether the proposal should create the partitions required for booting. If false, then the
      # {#boot_device} is ignored.
      #
      # @return [Boolean]
      attr_accessor :propose_boot

      # Set of volumes to create
      #
      # @return [Array<Volume>]
      attr_accessor :volumes

      def initialize
        @lvm = LvmSettings.new
        @encryption = EncryptionSettings.new
        @space = SpaceSettings.new
        @volumes = []
      end
    end
  end
end
