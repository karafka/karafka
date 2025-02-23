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

            # @return [Hash] consumer group setup with the parallel segments definition in it
            def to_h
              super.merge(
                parallel_segments: parallel_segments.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
