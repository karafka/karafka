# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class ParallelSegments < Base
          # Parallel segments are defined on the consumer group (since it creates many), thus we
          # define them on the consumer group.
          # This module adds extra methods needed there to make it work
          module ConsumerGroup
            # @return [Config] parallel segments config
            def parallel_segments
              # We initialize it as disabled if not configured by the user
              public_send(:parallel_segments=, count: 1)
            end

            # Allows setting parallel segments configuration
            #
            # @param count [Integer] number of parallel segments (number of parallel consumer
            #   groups that will be created)
            # @param partitioner [nil, #call] nil or callable partitioner
            # @param reducer [nil, #call] reducer for parallel key. It allows for using a custom
            #   reducer to achieve enhanced parallelization when the default reducer is not enough.
            # @param merge_key [String] key used to build the parallel segment consumer groups
            #
            # @note This method is an assignor but the API is actually via the `#parallel_segments`
            #   method. Our `Routing::Proxy` normalizes that the way we want to have it exposed
            #   for the end users.
            def parallel_segments=(
              count: 1,
              partitioner: nil,
              reducer: nil,
              merge_key: '-parallel-'
            )
              @parallel_segments ||= Config.new(
                active: count > 1,
                count: count,
                partitioner: partitioner,
                reducer: reducer || ->(parallel_key) { parallel_key.to_s.sum % count },
                merge_key: merge_key
              )
            end

            # @return [Boolean] are parallel segments active
            def parallel_segments?
              parallel_segments.active?
            end

            # @return [Integer] id of the segment (0 or bigger) or -1 if parallel segments are not
            #   active
            def segment_id
              return @segment_id if @segment_id

              @segment_id = if parallel_segments?
                              name.split(parallel_segments.merge_key).last.to_i
                            else
                              -1
                            end
            end

            # @return [String] original segment consumer group name
            def segment_origin
              name.split(parallel_segments.merge_key).first
            end

            # @return [Hash] consumer group setup with the parallel segments definition in it
            def to_h
              super.merge(
                parallel_segments: parallel_segments.to_h.merge(
                  segment_id: segment_id
                )
              ).freeze
            end
          end
        end
      end
    end
  end
end
