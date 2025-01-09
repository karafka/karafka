# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Pro components related to processing part of Karafka
    module Processing
      # Pro jobs
      module Jobs
        # The main job type in a non-blocking variant.
        # This variant works "like" the regular consumption but does not block the queue.
        #
        # It can be useful when having long lasting jobs that would exceed `max.poll.interval`
        # if would block.
        #
        # @note It needs to be working with a proper consumer that will handle the partition
        #   management. This layer of the framework knows nothing about Kafka messages consumption.
        class ConsumeNonBlocking < ::Karafka::Processing::Jobs::Consume
          self.action = :consume

          # Makes this job non-blocking from the start
          # @param args [Array] any arguments accepted by `::Karafka::Processing::Jobs::Consume`
          def initialize(*args)
            super
            @non_blocking = true
          end
        end
      end
    end
  end
end
