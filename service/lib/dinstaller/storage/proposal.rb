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
require "y2storage/proposal_settings"
require "y2storage/dialogs/guided_setup/helpers/disk"
require "dinstaller/with_progress"
require "dinstaller/storage/volume"

module DInstaller
  module Storage
    # Backend class to calculate a storage proposal
    class Proposal
      include WithProgress

      class NoProposalError < StandardError; end

      # Constructor
      #
      # @param logger [Logger]
      # @param config [Config]
      def initialize(logger, config)
        @logger = logger
        @config = config
        @listeners = []
      end

      def add_on_change_listener(&block)
        @listeners << block
      end

      def changed!
        @listeners.each(&:call)
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

      # Name of devices where to perform the installation
      #
      # @raise [NoProposalError] if no proposal yet
      #
      # @return [Array<String>]
      def candidate_devices
        raise NoProposalError unless proposal

        proposal.settings.candidate_devices
      end

      # Whether the proposal should create LVM devices
      #
      # @raise [NoProposalError] if no proposal yet
      #
      # @return [Boolean]
      def lvm?
        raise NoProposalError unless proposal

        proposal.settings.use_lvm
      end

      def volumes
        raise NoProposalError unless proposal

        Volume.from_proposal(proposal)
      end

      # Calculates a new proposal
      #
      # @param settings [Hash] settings to calculate the proposal
      #   (e.g., { "use_lvm" => true, "candidate_devices" => ["/dev/sda"]}). Note that keys should
      #   match with a public setter.
      # @param volumes [Array<Volume>] only these properties will be honored
      #   mount_point, filesystem_type, fixed_size_limits, min_size, max_size, snapshots
      # @return [Boolean] whether the proposal was correctly calculated
      def calculate(settings = {}, volumes: nil)
        proposal_settings = generate_proposal_settings(settings, volumes)

        @proposal = new_proposal(proposal_settings)
        storage_manager.proposal = proposal

        changed!

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

      # Generates proposal settings from the given values
      #
      # @param settings [Hash]
      # @param volumes [Array<Volume>, nil] ignored if nil or empty
      # @return [Y2Storage::ProposalSettings]
      def generate_proposal_settings(settings, volumes)
        proposal_settings = Y2Storage::ProposalSettings.new_for_current_product

        init_config_volumes(proposal_settings)
        Volume.adapt_settings(proposal_settings, volumes) if volumes&.any?

        settings.each { |k, v| proposal_settings.public_send("#{k}=", v) }

        proposal_settings
      end

      # Reads the list of volumes from the D-Installer configuration
      #
      # @return [Array<Y2Storage::VolumeSpecification>]
      def read_config_volumes
        vols = config.data.fetch("storage", {}).fetch("volumes", [])
        vols.map { |v| Y2Storage::VolumeSpecification.new(v) }
      end

      def init_config_volumes(proposal_settings)
        vol_specs = read_config_volumes
        # If no volumes are specified, just leave the default ones (hardcoded at Y2Storage)
        return if vol_specs.empty?

        proposal_settings.volumes = vol_specs
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
    end
  end
end
