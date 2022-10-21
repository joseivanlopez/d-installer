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

module DInstaller
  module Storage
    # Backend class to represent a volume blah
    class Volume
      class << self
        # When the proposal is already calculated, to show them
        def from_proposal(proposal)
          specs = proposal.settings.volumes
          specs.select(&:proposed).map do |spec|
            vol = new(proposal)
            vol.specification = spec
            vol.init_size_relevant_volumes(specs)
            vol
          end
        end

        def from_config(config)
          entries = config.data.fetch("storage", {}).fetch("volumes", [])
          specs = entries.map { |e| Y2Storage::VolumeSpecification.new(e) }
          specs.map do |spec|
            vol = new
            vol.specification = spec
            vol.init_size_relevant_volumes(specs)
            vol
          end
        end

        # When generating the proposal settings
        def adapt_settings(proposal_settings, volumes)
          proposal_settings.volumes.each do |spec|
            next unless spec.proposed_configurable?
            next if volumes.any? {|v| same_path?(v.mount_point, spec.mount_point) }
            spec.proposed = false
          end

          volumes.each do |vol|
            spec = proposal_settings.volumes.find {|v| same_path?(v.mount_point, vol.mount_point) }
            if spec
              proposal_settings.volumes.delete(spec)
              spec.proposed = true
              vol.specification = spec
            end
            proposal_settings.volumes.unshift(vol.specification)
          end
        end

        def same_path?(path1, path2)
          return false if path1.nil? || path2.nil?

          Pathname.new(path1).cleanpath == Pathname.new(path2).cleanpath 
        end
      end

      def initialize(proposal = nil)
        @proposal = proposal
        @size_relevant_volumes = []
      end

      attr_writer :mount_point
      attr_writer :fixed_size_limits
      attr_writer :min_size
      attr_writer :max_size
      attr_writer :fs_type
      attr_writer :snapshots
      attr_reader :proposal

      # Related volumes that may affect the calculation of the automatic size limits
      # @return [Array<String>]
      attr_reader :size_relevant_volumes

      # This syncs the specification, so maybe a setter is not the best way
      def specification=(spec)
        @specification = spec
        sync_to_specification
      end

      def specification
        return @specification if @specification

        # Maybe raise if no mount_point
        raise "No mount point" if @mount_point.nil?

        self.specification = Y2Storage::VolumeSpecification.new(mount_point: @mount_point)
        @specification
      end

      def sync_to_specification
        # Maybe check whether fixed makes sense
        if @fixed_size_limits
          @specification.ignore_fallback_sizes = true
          @specification.ignore_snapshots_sizes = true
          @specification.min_size = @min_size if @min_size
          @specification.max_size = @max_size if @max_size
        elsif @fixed_size_limits == false
          @specification.ignore_fallback_sizes = false
          @specification.ignore_snapshots_sizes = false
        end
        # Maybe some validation?
        @specification.fs_type = @filesystem_type if @filesystem_type
        @specification.snapshots = @snapshots unless @snapshots.nil?
      end

      def mount_point
        specification&.mount_point || @mount_point
      end

      # FIXME: should this always be true if adaptative_sizes? if false
      def fixed_size_limits
        return @fixed_size_limits unless specification
        return true unless adaptative_sizes?

        # We can check either #ignore_fallback_size or #ignore_snapshots_size, both are in sync
        specification.ignore_fallback_sizes
      end

      alias_method :fixed_size_limits?, :fixed_size_limits

      # @return [Y2Storage::DiskSize]
      def min_size
        planned_device&.min || specification&.min_size || @min_size
      end

      # @return [Y2Storage::DiskSize]
      def max_size
        planned_device&.max || specification&.max_size || @max_size
      end

      # First simplistic approach using symbols and respond_to?
      # @return [Symbol]
      def device_type
        return nil unless planned_device

        planned_device.respond_to?(:lv_type) ? :logical_volume : :partition
      end

      def filesystem_type
        specification&.fs_type || @filesystem_type
      end

      def filesystem_types
        specification&.fs_types || []
      end

      def snapshots
        specification&.snapshots || @snapshots
      end

      alias_method :snapshots?, :snapshots

      def snapshots_configurable?
        specification.snapshots_configurable
      end

      # Whether the device is encrypted directly or indirectly (eg. a LV in an encrypted LVM VG)
      #
      # This implementation is not future-proof because does not allow to mix encrypted and not
      # encrypted devices, but it will have to serve for now
      def encrypted?
        return nil unless proposal

        proposal.settings.use_encryption
      end

      # Whether it makes sense to have automatic size limits for this particular volume
      def adaptative_sizes?
        # FIXME this should be a responsibility of the Proposal (since it's calculated by
        # Proposal::DevicesPlanner)
        snapshots_affect_sizes? || size_relevant_volumes.any?
      end

      # Whether snapshots affect the automatic calculation of the size limits
      def snapshots_affect_sizes?
        # FIXME this should be a responsibility of the Proposal (since it's calculated by
        # Proposal::DevicesPlanner)
        return false unless specification
        return false unless specification.snapshots || specification.snapshots_configurable
        return true if specification.snapshots_size && !specification.snapshots_size.zero?

        specification.snapshots_percentage && !specification.snapshots_percentage.zero?
      end

      def init_size_relevant_volumes(specs)
        # FIXME this should be a responsibility of the Proposal (since it's calculated by
        # Proposal::DevicesPlanner)
        @size_relevant_volumes = specs.select { |v| fallback?(v, mount_point) }.map(&:mount_point)
      end

    private

      def planned_device
        return nil unless proposal

        @planned_device ||= proposal.planned_devices.find do |dev|
          dev.respond_to?(:mount_point) && same_path?(dev.mount_point, mount_point)
        end
      end

      def same_path?(*args)
        self.class.same_path?(*args)
      end

      def fallback?(spec, mount_point)
        same_path?(spec.fallback_for_min_size, mount_point) ||
          same_path?(spec.fallback_for_max_size, mount_point) ||
          same_path?(spec.fallback_for_max_size_lvm, mount_point)
      end
    end
  end
end
