# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      module Strategies
        # Long-Running Job enabled
        # Virtual Partitions enabled
        module LrjVp
          # Same flow as the standard Lrj
          include Lrj

          # Features for this strategy
          FEATURES = %i[
            long_running_job
            virtual_partitions
          ].freeze
        end
      end
    end
  end
end
