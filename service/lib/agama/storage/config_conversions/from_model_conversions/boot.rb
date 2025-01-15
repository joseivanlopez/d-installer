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

require "agama/storage/config_conversions/from_model_conversions/base"
require "agama/storage/config_conversions/from_model_conversions/boot_device"
require "agama/storage/configs/boot"

module Agama
  module Storage
    module ConfigConversions
      module FromModelConversions
        # Boot conversion from model according to the JSON schema.
        class Boot < Base
        private

          # @see Base
          # @return [Configs::Boot]
          def default_config
            Configs::Boot.new
          end

          # @see Base#conversions
          # @return [Hash]
          def conversions
            {
              configure: model_json[:configure],
              device:    convert_device
            }
          end

          # @return [Configs::BootDevice, nil]
          def convert_device
            boot_device_model = model_json[:device]
            return if boot_device_model.nil?

            FromModelConversions::BootDevice.new(boot_device_model).convert
          end
        end
      end
    end
  end
end