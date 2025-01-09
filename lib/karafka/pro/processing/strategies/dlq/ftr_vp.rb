# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # - DLQ
          # - Ftr
          # - VPs
          #
          # Behaves same as non-VP due to coordinator lock
          module FtrVp
            include Strategies::Vp::Default
            include Strategies::Dlq::Vp
            include Strategies::Dlq::Ftr

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
