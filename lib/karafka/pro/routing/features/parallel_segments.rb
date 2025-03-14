# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Feature that allows parallelizing message processing within a single consumer group by
        # creating multiple consumer group instances. It enables processing messages from each
        # partition in parallel by distributing them to separate consumer group instances based on
        # a partitioning key. Useful for both CPU and IO bound operations.
        #
        # Each parallel segment operates as an independent consumer group instance, processing
        # messages that are assigned to it based on the configured partitioner and reducer.
        # This allows for better resource utilization and increased processing throughput without
        # requiring changes to the topic's partition count.
        class ParallelSegments < Base
        end
      end
    end
  end
end
