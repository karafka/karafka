# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # Dead-Letter Queue enabled
          # MoM enabled
          # Virtual Partitions enabled
          module MomVp
            include Strategies::Dlq::Vp
            include Strategies::Dlq::Mom

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              manual_offset_management
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
