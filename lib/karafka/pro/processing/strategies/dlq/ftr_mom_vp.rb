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
          # - Mom
          # - VP
          # We can use the `Strategies::FtrMom` because VPs collapse prior to DLQ
          module FtrMomVp
            include Strategies::Mom::Vp
            include Strategies::Dlq::Vp
            include Strategies::Dlq::FtrMom

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              manual_offset_management
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
