# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # Dead-Letter Queue enabled
          # Filtering enabled
          # Long-Running Job enabled
          # Virtual Partitions
          module FtrLrjVp
            include Strategies::Vp::Default
            include Strategies::Dlq::Vp
            # Same as non VP because of the coordinator post-execution lock
            include Strategies::Dlq::FtrLrj

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              long_running_job
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
