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

require "agama/storage/device_settings"
require "agama/storage/volume_conversion"

module Agama
  module Storage
    module ProposalSettingsConversion
      # Proposal settings conversion according to JSON schema.
      class ToSchema
        # @param settings [Agama::Storage::ProposalSettings]
        def initialize(settings)
          @settings = settings
        end

        # Performs the conversion according to JSON schema.
        #
        # @return [Hash]
        def convert
          {
            target:     target_conversion,
            boot:       boot_conversion,
            encryption: encryption_conversion,
            space:      space_conversion,
            volumes:    volumes_conversion
          }
        end

      private

        # @return [Agama::Storage::ProposalSettings]
        attr_reader :settings

        def target_conversion
          device_settings = settings.device

          case device_settings
          when Agama::Storage::DeviceSettings::Disk
            { disk: device_settings.name || "" }
          when Agama::Storage::DeviceSettings::NewLvmVg
            { newLvmVg: device_settings.candidate_pv_devices }
          end
        end

        def boot_conversion
          {
            configure: settings.boot.configure?,
            device:    settings.boot.device
          }
        end

        def encryption_conversion
          {
            password:     settings.encryption.password.to_s,
            method:       settings.encryption.method.id.to_s,
            pbkdFunction: settings.encryption.pbkd_function&.value
          }
        end

        def space_conversion
          {
            policy:  settings.space.policy.to_s,
            actions: settings.space.actions.map { |d, a| { a => d} }
          }
        end

        def volumes_conversion
          settings.volumes.map { |v| VolumeConversion.to_schema(v) }
        end
      end
    end
  end
end
