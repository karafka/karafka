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
    # Pro components related to processing part of Karafka
    module Processing
      # Pro jobs
      module Jobs
        # The main job type in a non-blocking variant.
        # This variant works "like" the regular consumption but pauses the partition for as long
        # as it is needed until a job is done.
        #
        # It can be useful when having long lasting jobs that would exceed `max.poll.interval`
        # if would block.
        #
        # @note It needs to be working with a proper consumer that will handle the partition
        #   management. This layer of the framework knows nothing about Kafka messages consumption.
        class ConsumeNonBlocking < ::Karafka::Processing::Jobs::Consume
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
