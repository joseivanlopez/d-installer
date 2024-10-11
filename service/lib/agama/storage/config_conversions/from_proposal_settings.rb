# frozen_string_literal: true

# Copyright (c) [2024] SUSE LLC
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

require "agama/storage/config"
require "agama/storage/configs"
require "agama/storage/device_settings"

module Agama
  module Storage
    module ConfigConversions
      # Config conversion from {ProposalSettings}.
      class FromProposalSettings
        # @param proposal_settings [ProposalSettings]
        def initialize(proposal_settings, devicegraph)
          @proposal_settings = proposal_settings
          @devicegraph = devicegraph
        end

        # Performs the conversion from {ProposalSettings}.
        #
        # @return [Storage::Config]
        def convert
          @config = Storage::Config.new
          convert_drives
        end

      private

        # @return [ProposalSettings]
        attr_reader :proposal_settings

        attr_reader :devicegraph

        # @return [Storage::Config]
        attr_reader :config

        def convert_drives
          convert_default_drive
          convert_drives_from_volumes
          convert_drives_from_space_settings
        end

        def convert_volume_groups
          convert_default_volume_group
          convert_volume_groups_from_volumes
          convert_volume_groups_from_space_settings
        end

        def convert_default_drive
          return unless proposal_settings.device.is_a?(DeviceSettings::Disk)

          ensure_drive_for(proposal_settings.device.name).tap do |drive|
            drive.partitions.concat(convert_default_partitions)
          end
        end

        def convert_drives_from_volumes
          settings.volumes.each { |v| convert_drive_from_volume(v) }

        end

        def convert_drive_from_volume(volume)
          device = find_device(volume)
          return unless device&.is?(:disk_device)


        end

        def convert_default_partitions
          default_volumes.map { |v| convert_partition_from_volume(v) }
        end

        def convert_partition_from_volume(volume)
          partition_device = find_device(volume)&.is?(:partition)
          reuse = volume.location.reuse_device?

          Configs::Partition.new.tap do |partition|
            partition.search = convert_search(volume) if partition_device
            partition.encryption = convert_encryption unless reuse
            partition.filesystem = convert_filesystem(volume)
            partition.size = convert_size(volume)
          end
        end

        def convert_search(volume)
          device = volume.location.device
          return unless device

          Configs::Search.new.tap do |search|
            search.name = device
          end
        end

        def convert_encryption
          Configs::Encrypton.new.tap do |encryption|
            encryption.method = settings.encryption.method
            encryption.password = settings.encryption.password
            encryption.pbdk_function = settings.encryption.pbkd_function
          end
        end

        def convert_filesystem(volume)
          Configs::Filesystem.new.tap do |filesystem|
            filesystem.reuse = volume.location.target == :filesystem
            filesystem.type = convert_filesystem_type(volume)
          end
        end

        def convert_fileystem_type(volume)
          return unless volume.fs_type

          Configs::FilesystemType.new.tap do |type|
            type.fs_type = volume.fs_type
            type.btrfs = volume.btrfs
          end
        end

        def convert_size(volume)
          Configs::Size.new.tap do |size|
            size.default = volume.auto_size?
            size.min = volume.min_size
            size.max = volume.max_size
          end
        end

        # Recovers or adds a drive for the given device.
        #
        # @param device
        def ensure_drive_for(device)
          find_drive_for(device) || add_drive_for(device)
        end

        def find_drive_for(device)
          config.drives.find { |d| d.search.name == device }
        end

        def add_drive_for(device)
          drive = Configs::Drive.new.tap { |d| d.search.name = device }
          config.drives << drive

          drive
        end

        def default_volumes
          settings.volumes.select { |v| v.location.target == :default }
        end

        # @return [Y2Storage::Device, nil]
        def find_device(volume)
          device_name = volume.location.device
          return unless device_name

          devicegraph.find_by_any_name(device_name)
        end
      end
    end
  end
end
