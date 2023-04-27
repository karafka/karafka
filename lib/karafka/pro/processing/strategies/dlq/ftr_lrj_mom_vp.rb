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
          # DLQ enabled
          # Ftr enabled
          # LRJ enabled
          # MoM enabled
          # VP enabled
          module FtrLrjMomVp
            include Strategies::Vp::Default
            include Strategies::Dlq::Vp
            # Same as non VP because of the coordinator post-execution lock
            include Strategies::Dlq::FtrLrjMom

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
