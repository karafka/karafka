# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Mom
          # - Mom enabled
          # - Vp enabled
          module Vp
            include Strategies::Vp::Default
            include Strategies::Mom::Default

            # Features of this strategy
            FEATURES = %i[
              manual_offset_management
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
