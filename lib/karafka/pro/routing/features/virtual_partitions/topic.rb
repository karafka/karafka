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
    module Routing
      module Features
        class VirtualPartitions < Base
          # Topic extensions to be able to manage virtual partitions feature
          module Topic
            # @param max_partitions [Integer] max number of virtual partitions that can come out of
            #   the single distribution flow. When set to more than the Karafka threading, will
            #   create more work than workers. When less, can ensure we have spare resources to
            #   process other things in parallel.
            # @param partitioner [nil, #call] nil or callable partitioner
            # @param offset_metadata_strategy [Symbol] how we should match the metadata for the
            #   offset. `:exact` will match the offset matching metadata and `:current` will select
            #   the most recently reported metadata
            # @param reducer [nil, #call] reducer for VPs key. It allows for using a custom
            #   reducer to achieve enhanced parallelization when the default reducer is not enough.
            # @return [VirtualPartitions] method that allows to set the virtual partitions details
            #   during the routing configuration and then allows to retrieve it
            def virtual_partitions(
              max_partitions: Default.new(Karafka::App.config.concurrency),
              partitioner: Default.new,
              offset_metadata_strategy: Default.new(:current),
              # If no reducer provided, we use this one. It just runs a modulo on the sum of
              # a stringified version, providing fairly good distribution.
              reducer: Default.new(->(virtual_key) { virtual_key.to_s.sum % max_partitions })
            )
              @virtual_partitions ||= Config.new( max_partitions: max_partitions,
                                                  partitioner: partitioner,
                                                  offset_metadata_strategy: offset_metadata_strategy,
                                                  reducer: reducer
              )
              if Config.all_defaults?(max_partitions, partitioner, offset_metadata_strategy, reducer)
                return @virtual_partitions
              end

              @virtual_partitions.max_partitions = max_partitions
              @virtual_partitions.partitioner = partitioner
              @virtual_partitions.offset_metadata_strategy = offset_metadata_strategy
              @virtual_partitions.active = !@virtual_partitions.partitioner.nil?
              @virtual_partitions.reducer = reducer
              @virtual_partitions
            end

            # @return [Boolean] are virtual partitions enabled for given topic
            def virtual_partitions?
              virtual_partitions.active?
            end

            # @return [Hash] topic with all its native configuration options plus manual offset
            #   management namespace settings
            def to_h
              super.merge(
                virtual_partitions: virtual_partitions.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
