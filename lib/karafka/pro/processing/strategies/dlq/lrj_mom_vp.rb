# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # Strategy for supporting DLQ with Mom, LRJ and VP enabled
          module LrjMomVp
            # Feature set for this strategy
            FEATURES = %i[
              dead_letter_queue
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze

            include Strategies::Dlq::Vp
            include Strategies::Dlq::LrjMom
          end
        end
      end
    end
  end
end
