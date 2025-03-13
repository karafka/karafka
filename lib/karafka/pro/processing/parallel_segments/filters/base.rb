# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module ParallelSegments
        # Module for filters injected into the processing pipeline of each of the topics used
        # within the parallel segmented consumer groups
        module Filters
          # Base class for filters for parallel segments that deal with different feature scenarios
          class Base < Processing::Filters::Base
            # @param segment_id [Integer] numeric id of the parallel segment group to use with the
            #   partitioner and reducer for segment matching comparison
            # @param partitioner [Proc]
            # @param reducer [Proc]
            def initialize(segment_id:, partitioner:, reducer:)
              super()

              @segment_id = segment_id
              @partitioner = partitioner
              @reducer = reducer
            end

            private

            # @param message [Karafka::Messages::Message] received message
            # @return [String, Numeric] segment assignment key
            def partition(message)
              @partitioner.call(message)
            rescue StandardError => e
              # This should not happen. If you are seeing this it means your partitioner code
              # failed and raised an error. We highly recommend mitigating partitioner level errors
              # on the user side because this type of collapse should be considered a last resort
              Karafka.monitor.instrument(
                'error.occurred',
                caller: self,
                error: e,
                message: message,
                type: 'parallel_segments.partitioner.error'
              )

              :failure
            end

            # @param message_segment_key [String, Numeric] segment key to pass to the reducer
            # @return [Integer] segment assignment of a given message
            def reduce(message_segment_key)
              # Assign to segment 0 always in case of failures in partitioner
              # This is a fail-safe
              return 0 if message_segment_key == :failure

              @reducer.call(message_segment_key)
            rescue StandardError => e
              # @see `#partition` method error handling doc
              Karafka.monitor.instrument(
                'error.occurred',
                caller: self,
                error: e,
                message_segment_key: message_segment_key,
                type: 'parallel_segments.reducer.error'
              )

              0
            end
          end
        end
      end
    end
  end
end
