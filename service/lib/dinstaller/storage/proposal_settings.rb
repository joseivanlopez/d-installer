# frozen_string_literal: true

# Copyright (c) [2022] SUSE LLC
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

require "pathname"
require "y2storage"
require "dinstaller/storage/volume"

module DInstaller
  module Storage
    # Backend class to represent the settings passed to Proposal#calculate
    class ProposalSettings
      include Y2Storage::SecretAttributes

      # @return [Boolean] whether to use LVM
      attr_accessor :use_lvm
      alias_method :use_lvm?, :use_lvm

      # @!attribute encryption_password
      #   @return [String] password to use when creating new encryption devices
      secret_attr :encryption_password

      # Device names of the disks that can be used for the installation. If nil,
      # the proposal will try find suitable devices
      #
      # @return [Array<String>, nil]
      attr_accessor :candidate_devices

      # Set of volumes to create
      #
      # Only these properties will be honored: mount_point, filesystem_type, fixed_size_limits,
      # min_size, max_size, snapshots
      #
      # @return [Array<Volume>]
      attr_accessor :volumes

      # @param config [Config]
      def initialize(config)
        @config = config
        @use_lvm = false
        @volumes = []
      end

      # Whether encryption must be used
      # @return [Boolean]
      def use_encryption
        !encryption_password.nil?
      end
      alias_method :use_encryption?, :use_encryption

      # List of all the printable general settings
      DISPLAYED_SETTINGS = [:candidate_devices, :use_lvm, :use_encryption].freeze
      private_constant :DISPLAYED_SETTINGS

      def to_s
        "Storage ProposalSettings\n" \
          "  general settings:\n" +
          DISPLAYED_SETTINGS.map { |s| "    #{s}: #{send(s)}\n" }.join +
          "  volumes:\n" \
          "    #{volumes}"
      end

      # Generates a Y2Storage::ProposalSettings object from the given values
      #
      # @return [Y2Storage::ProposalSettings]
      def to_y2storage
        settings = Y2Storage::ProposalSettings.new_for_current_product

        init_config_volumes(settings)
        Volume.adapt_settings(settings, volumes) if volumes&.any?

        settings.use_lvm = use_lvm
        settings.encryption_password = encryption_password
        settings.candidate_devices = candidate_devices

        settings
      end

    private

      # @return [Config]
      attr_reader :config

      # @param settings [Y2Storage::ProposalSettings]
      def init_config_volumes(settings)
        vol_specs = Volume.from_config(config).map(&:specification)
        # If no volumes are specified, just leave the default ones (hardcoded at Y2Storage)
        return if vol_specs.empty?

        settings.volumes = vol_specs
      end
    end
  end
end
