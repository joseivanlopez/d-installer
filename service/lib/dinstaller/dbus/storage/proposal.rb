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

require "dbus"
require "dinstaller/dbus/base_object"
require "dinstaller/dbus/with_service_status"
require "dinstaller/dbus/interfaces/service_status"
require "dinstaller/storage/proposal_settings"

module DInstaller
  module DBus
    module Storage
      # D-Bus object to manage a storage proposal
      class Proposal < BaseObject
        include WithServiceStatus
        include Interfaces::ServiceStatus

        PATH = "/org/opensuse/DInstaller/Storage/Proposal1"
        private_constant :PATH

        # Constructor
        #
        # @param backend [DInstaller::Storage::Proposal]
        # @param logger [Logger]
        def initialize(backend, logger)
          super(PATH, logger: logger)
          @backend = backend

          register_callbacks
          register_service_status_callbacks
        end

        STORAGE_PROPOSAL_INTERFACE = "org.opensuse.DInstaller.Storage.Proposal1"
        private_constant :STORAGE_PROPOSAL_INTERFACE

        dbus_interface STORAGE_PROPOSAL_INTERFACE do
          dbus_reader :lvm, "b", dbus_name: "LVM"

          dbus_reader :candidate_devices, "as"

          # The first string is the name of the device (as expected by #Calculate for
          # the setting CandidateDevices), the second one is the label to represent that device in
          # the UI when further information is needed.
          dbus_reader :available_devices, "a(ssa{sv})"

          dbus_reader :encryption_password, "s"

          dbus_reader :volumes, "aa{sv}"

          dbus_reader :volume_templates, "aa{sv}"

          dbus_reader :actions, "aa{sv}"

          # result: 0 success; 1 error
          dbus_method :Calculate, "in settings:a{sv}, out result:u" do |settings|
            success = busy_while do
              backend.calculate(to_proposal_settings(settings))
            end

            success ? 0 : 1
          end
        end

        # List of disks available for installation
        #
        # Each device is represented by an array containing id and UI label. See the documentation
        # of the available_devices DBus reader.
        #
        # @see DInstaller::Storage::Proposal
        #
        # @return [Array<Array>]
        def available_devices
          backend.available_devices.map do |dev|
            [dev.name, backend.device_label(dev), {}]
          end
        end

        # @see DInstaller::Storage::Proposal
        def lvm
          return false unless backend.settings

          backend.settings.lvm?
        end

        # @see DInstaller::Storage::Proposal
        def candidate_devices
          return [] unless backend.settings

          backend.settings.candidate_devices
        end

        def encryption_password
          return "" unless backend.settings

          backend.settings.encryption_password
        end

        def volumes
          backend.volumes.map { |v| to_dbus_volume(v) }
        end

        # List of sorted actions in D-Bus format
        #
        # @see #to_dbus_action
        #
        # @return [Array<Hash>]
        def actions
          backend.actions.all.map { |a| to_dbus_action(a) }
        end

      private

        # @return [DInstaller::Storage::Proposal]
        attr_reader :backend

        # @return [Logger]
        attr_reader :logger

        # Registers callback to be called when properties change
        def register_callbacks
          backend.on_calculate do
            properties = interfaces_and_properties[STORAGE_PROPOSAL_INTERFACE]
            dbus_properties_changed(STORAGE_PROPOSAL_INTERFACE, properties, [])
          end
        end

        # Converts settings from D-Bus to backend names
        #
        # @param settings [Hash]
        def to_proposal_settings(dbus_settings)
          ProposalSettings.new.tap do |proposal_settings|
            dbus_settings.each do |dbus_property, dbus_value|
              setter, value = case dbus_property
                when "CandidateDevices"
                  ["candidate_devices=", dbus_value]
                when "LVM"
                  ["use_lvm=", dbus_value]
                when "EncryptionPassword"
                  ["encryption_password=", dbus_value]
                when "Volumes"
                  ["volumes=", dbus_value.map { |v| to_proposal_volume(v) }]
                end

              proposal_settings.public_send(setter, value)
            end
          end
        end

        def to_proposal_volume(dbus_volume)
          Volume.new.tap do |volume|
            dbus_volume.each do |dbus_property, dbus_value|
              setter, value = case dbus_property
                when "DeviceType"
                  ["device_type=", dbus_value.to_sym]
                when "Encrypted"
                  ["encrypted=", dbus_value]
                when "MountPoint"
                  ["mount_point=", dbus_value]
                when "FixedSizeLimits"
                  ["fixed_size_limits=", dbus_value]
                when "MinSize"
                  ["min_size=", Y2Storage::DiskSize.new(dbus_value)]
                when "MaxSize"
                  ["max_size=", Y2Storage::DiskSize.new(dbus_value)]
                when "FSType"
                  ["fs_type=", to_fs_type(dbus_value)]
                when "Snapshots"
                  ["snapshots=", dbus_value]
                end

              volume.public_send(setter, value)
            end
          end
        end

        def to_fs_type(dbus_fs_type)
          Y2Storage::Filesystems::Type.all.find { |t| t.to_human_string == dbus_fs_type }
        end

        def to_dbus_volume(volume)
          {
            "DeviceType"               => volume.device_type.to_s,
            "Optional"                 => volume.optional?,
            "Encrypted"                => volume.encrypted?,
            "FixedSizeLimits"          => volume.fixed_size_limits?,
            "AdaptativeSizes"          => volume.adaptative_sizes?,
            "MinSize"                  => volume.min_size.to_i,
            "MaxSize"                  => volume.max_size.to_i,
            "FsTypes"                  => volume.fs_types.map(&:to_human_string),
            "FsType"                   => volume.fs_type.to_human_string,
            "Snapshots"                => volume.snapshots?,
            "SnapshotsConfigurable"    => volume.snapshots_configurable?,
            "SnapshotsAffectSizes"     => volume.snapshots_affect_sizes?,
            "SizeRelevantVolumes"      => volume.size_relevant_volumes
          }
        end

        # Converts an action to D-Bus format
        #
        # @param action [Y2Storage::CompoundAction]
        # @return [Hash]
        def to_dbus_action(action)
          {
            "Text"   => action.sentence,
            "Subvol" => action.device_is?(:btrfs_subvolume),
            "Delete" => action.delete?
          }
        end
      end
    end
  end
end
