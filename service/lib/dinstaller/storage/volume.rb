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

require "forwardable"
require "pathname"
require "y2storage/volume_specification"

module DInstaller
  module Storage
    # Backend class to represent a volume blah
    class Volume
      extend Forwardable

      attr_reader :spec

      attr_accessor :device_type
      attr_accessor :encrypted

      # Related volumes that may affect the calculation of the automatic size limits
      # @return [Array<String>]
      attr_reader :size_relevant_volumes

      def_delegator :@spec, :mount_point
      def_delegator :@spec, :mount_point=
      def_delegator :@spec, :min_size
      def_delegator :@spec, :min_size=
      def_delegator :@spec, :max_size
      def_delegator :@spec, :max_size=
      def_delegator :@spec, :fs_types
      def_delegator :@spec, :fs_type
      def_delegator :@spec, :fs_type=
      def_delegator :@spec, :snapshots?
      def_delegator :@spec, :snapshots=
      def_delegator :@spec, :snapshots_configurable?
      def_delegator :@spec, :proposed_configurable?, :optional?
      def_delegator :@spec, :proposed_configurable=, :optional=

      def initialize(spec = nil)
        @spec = spec || Y2Storage::VolumeSpecification.new
        @spec.proposed = true
        @spec.proposed_configurable = false

        @device_type = :partition
        @encrypted = false
        @size_relevant_volumes = []
      end

      def assign_size_relevant_volumes(specs)
        # FIXME this should be a responsibility of the Proposal (since it's calculated by
        # Proposal::DevicesPlanner)
        @size_relevant_volumes = specs.select { |s| fallback?(s) }.map(&:mount_point)
      end

      # FIXME: should this always be true if adaptative_sizes? if false
      def fixed_size_limits?
        return true unless adaptative_sizes?

        # We can check either #ignore_fallback_size or #ignore_snapshots_size, both are in sync
        spec.ignore_fallback_sizes?
      end

      def fixed_size_limits=(value)
        # Maybe check whether fixed makes sense
        spec.ignore_fallback_sizes = value
        spec.ignore_snapshots_sizes = value
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
        return false unless snapshots? || snapshots_configurable?
        return true if spec.snapshots_size && !spec.snapshots_size.zero?

        spec.snapshots_percentage && !spec.snapshots_percentage.zero?
      end

      def mounted_at?(path)
        return false if mount_point.nil? || path.nil?

        Pathname.new(mount_point).cleanpath == Pathname.new(path).cleanpath
      end

    private

      def fallback?(spec)
        mounted_at?(spec.fallback_for_min_size) ||
          mounted_at?(spec.fallback_for_max_size) ||
          mounted_at?(spec.fallback_for_max_size_lvm)
      end
    end
  end
end
