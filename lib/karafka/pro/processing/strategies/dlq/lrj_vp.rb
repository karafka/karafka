# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # Dead-Letter Queue enabled
          # Long-Running Job enabled
          # Virtual Partitions enabled
          module LrjVp
            # Same flow as the Dlq Lrj because VP collapses on errors, so DlqLrj can kick in
            include Strategies::Vp::Default
            include Strategies::Dlq::Vp
            include Strategies::Dlq::Lrj

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              long_running_job
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
