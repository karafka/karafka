# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # Dead Letter Queue enabled
          # Virtual Partitions enabled
          #
          # In general because we collapse processing in virtual partitions to one on errors, there
          # is no special action that needs to be taken because we warranty that even with VPs
          # on errors a retry collapses into a single state and from this single state we can
          # mark as consumed the message that we are moving to the DLQ.
          module Vp
            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              virtual_partitions
            ].freeze

            include Strategies::Dlq::Default
            include Strategies::Vp::Default
          end
        end
      end
    end
  end
end
