# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
