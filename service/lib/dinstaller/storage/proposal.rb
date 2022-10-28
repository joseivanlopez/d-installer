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

require "y2storage/storage_manager"
require "y2storage/guided_proposal"
require "y2storage/dialogs/guided_setup/helpers/disk"
require "dinstaller/with_progress"
require "dinstaller/storage/volume"
require "dinstaller/storage/proposal_settings"

module DInstaller
  module Storage
    # Backend class to calculate a storage proposal
    class Proposal
      include WithProgress

      # Constructor
      #
      # @param logger [Logger]
      # @param config [Config]
      def initialize(logger, config)
        @logger = logger
        @config = config
        @on_calculate_callbacks = []
      end

      def on_calculate(&block)
        @on_calculate_callbacks << block
      end

      # Available devices for installation
      #
      # @return [Array<Y2Storage::Device>]
      def available_devices
        disk_analyzer.candidate_disks
      end

      # Label that should be used to represent the given disk in the UI
      #
      # NOTE: this is likely a temporary solution. The label should not be calculated in the backend
      # in the future. See the note about available_devices at {DBus::Storage::Proposal}.
      #
      # The label has the form: "NAME, SIZE, [USB], INSTALLED_SYSTEMS".
      #
      # Examples:
      #
      #   "/dev/sda, 250.00 GiB, Windows, OpenSUSE"
      #   "/dev/sdb, 8.00 GiB, USB"
      #
      # @param device [Y2Storage::Device]
      # @return [String]
      def device_label(device)
        disk_helper.label(device)
      end

      # Settings that were used to calculate the proposal
      #
      # @return [ProposalSettings, nil]
      def settings
        return nil unless proposal

        @settings
      end

      # Volume definitions to be used as templates in the interface
      #
      # Based on the configuration and/or on Y2Storage internals, these volumes may really
      # exist or not in the real context of the proposal and its settings.
      #
      # @return [Array<Volumes>]
      def volume_templates
        VolumesGenerator.new(specs_from_config).volumes
      end

      # Volumes used during the calculation of the proposal
      #
      # Not to be confused with settings.volumes, which are used as starting point
      #
      # @return [Array<Volumes>]
      def calculated_volumes
        return [] unless proposal

        generator = VolumesGenerator.new(specs_from_proposal,
          planned_devices: proposal.planned_devices)

        volumes = generator.volumes(only_proposed: true)

        volumes.each do |volume|
          config_spec = config_spec_for(volume)
          volume.optional = config_spec.proposed_configurable? if config_spec
          volume.encrypted = proposal.settings.use_encryption
        end

        volumes
      end

      def default_settings
        ProposalSettings.new.tap do |settings|
          generator = VolumesGenerator.new(specs_from_config)
          volumes = generator.volumes(only_proposed: true)
          volumes.map { |v| v.encrypted = settings.use_encryption? }

          settings.volumes = volumes
        end
      end

      # Calculates a new proposal
      #
      # @param settings [ProposalSettings] settings to calculate the proposal
      # @return [Boolean] whether the proposal was correctly calculated
      def calculate(settings = nil)
        @settings = settings || default_settings
        @settings.freeze
        proposal_settings = to_y2storage_settings(@settings)

        @proposal = new_proposal(proposal_settings)
        storage_manager.proposal = proposal

        @on_calculate_callbacks.each(&:call)

        !proposal.failed?
      end

      # Storage actions manager
      #
      # @fixme this method should directly return the actions
      #
      # @return [Storage::Actions]
      def actions
        # FIXME: this class could receive the storage manager instance
        @actions ||= Actions.new(logger)
      end

    private

      # @return [Logger]
      attr_reader :logger

      # @return [Config]
      attr_reader :config

      # @return [Y2Storage::InitialGuidedProposal]
      attr_reader :proposal

      def new_proposal(proposal_settings)
        guided = Y2Storage::MinGuidedProposal.new(
          settings:      proposal_settings,
          devicegraph:   probed_devicegraph,
          disk_analyzer: disk_analyzer
        )
        guided.propose
        guided
      end

      def specs_from_config
        config_volumes = config.data.fetch("storage", {}).fetch("volumes", [])
        config_volumes.map { |v| Y2Storage::VolumeSpecification.new(v) }
      end

      def specs_from_proposal
        return [] unless proposal

        proposal.settings.volumes
      end

      def config_spec_for(volume)
        specs_from_config.find { |s| volume.mounted_at?(s.mount_point) }
      end

      def to_y2storage_settings(settings)
        generator = ProposalSettingsGenerator.new(settings,
          default_volume_specs: specs_from_config,
          available_devices:    available_devices)
        generator.proposal_settings
      end

      # @return [Y2Storage::DiskAnalyzer]
      def disk_analyzer
        storage_manager.probed_disk_analyzer
      end

      # Helper to generate a disk label
      #
      # @return [Y2Storage::Dialogs::GuidedSetup::Helpers::Disk]
      def disk_helper
        @disk_helper ||= Y2Storage::Dialogs::GuidedSetup::Helpers::Disk.new(disk_analyzer)
      end

      # Devicegraph representing the system
      #
      # @return [Y2Storage::Devicegraph]
      def probed_devicegraph
        storage_manager.probed
      end

      def storage_manager
        Y2Storage::StorageManager.instance
      end

      class VolumesGenerator
        def initialize(specs, planned_devices: [])
          @specs = specs
          @plannend_devices = planned_devices
        end

        def volumes(only_proposed: false)
          specs = self.specs
          specs = specs.select(&:proposed?) if only_proposed

          specs.map do |spec|
            Volume.new(spec).tap do |volume|
              volume.assign_size_relevant_volumes(self.specs)
              planned = planned_device_for(volume)
              if planned
                volume.device_type = planned.respond_to?(:lv_type) ? :logical_volume : :partition
                volume.min_size = planned.min
                volume.max_size = planned.max
              end
            end
          end
        end

        private

        attr_reader :specs

        attr_reader :planned_devices

        def planned_device_for(volume)
          return nil if planned_devices.none?

          planned_devices.find do |device|
            device.respond_to?(:mount_point) && volume.mounted_at?(device.mount_point)
          end
        end
      end

      class ProposalSettingsGenerator
        def initialize(settings, default_volume_specs: [], available_devices: [])
          @settings = settings
          @default_volume_specs = default_volume_specs
          @available_devices = available_devices
        end

        def proposal_settings
          return @proposal_settings if @proposal_settings

          @proposal_settings = Y2Storage::ProposalSettings.new_for_current_product
          @proposal_settings.use_lvm = settings.use_lvm?
          @proposal_settings.encryption_password = settings.encryption_password
          @proposal_settings.candidate_devices = calculate_candidate_devices
          @proposal_settings.volumes = calculate_volume_specs

          @proposal_settings
        end

        private

        attr_reader :settings

        attr_reader :default_volume_specs

        attr_reader :available_devices

        def calculate_candidate_devices
          # FIXME
          return ["/dev/vdc"]

          candidate_devices = settings.candidate_devices

          if candidate_devices.none?
            # TODO: smart selection for the default disk
            candidate_devices = [available_devices.first&.name].compact
          end

          candidate_devices
        end

        def calculate_volume_specs
          settings.volumes.map(&:spec) + missing_volume_specs.map { |s| s.proposed = false }
        end

        def missing_volume_specs
          default_volume_specs.select { |s| missing_volume_spec?(s) }
        end

        def missing_volume_spec?(spec)
          settings.volumes.none? { |v| v.mounted_at?(spec.mount_point) }
        end
      end
    end
  end
end
