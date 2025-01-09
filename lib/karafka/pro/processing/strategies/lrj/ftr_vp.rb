# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Lrj
          # Long-Running Job enabled
          # Filtering enabled
          # Virtual Partitions enabled
          #
          # Behaves same as non-VP because of the aggregated flow in the coordinator.
          module FtrVp
            include Strategies::Vp::Default
            include Strategies::Lrj::Ftr

            # Features for this strategy
            FEATURES = %i[
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
