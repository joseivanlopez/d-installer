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

require "agama/storage/config_conversions/to_model_conversions/base"
require "agama/storage/configs/size"

module Agama
  module Storage
    module ConfigConversions
      module ToModelConversions
        # Size conversion to model according to the JSON schema.
        class Size < Base
          # @see Base
          def self.config_type
            Configs::Size
          end

        private

          # @see Base#conversions
          def conversions
            {
              default: config.default?,
              min:     config.min&.to_i,
              max:     convert_max_size
            }
          end

          # @return [Integer, nil]
          def convert_max_size
            max = config.max
            return if max.nil? || max.unlimited?

            max.to_i
          end
        end
      end
    end
  end
end