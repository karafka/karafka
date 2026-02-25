# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Routing
      module Features
        class VirtualPartitions < Base
          # Topic extensions to be able to manage virtual partitions feature
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @virtual_partitions = nil
            end

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
            # @param distribution [Symbol] the strategy to use for virtual partitioning. Can be
            #   either `:consistent` or `:balanced`. The `:balanced` strategy ensures balanced
            #   distribution of work across available workers while maintaining message order
            #   within groups.
            # @return [VirtualPartitions] method that allows to set the virtual partitions details
            #   during the routing configuration and then allows to retrieve it
            def virtual_partitions(
              max_partitions: Karafka::App.config.concurrency,
              partitioner: nil,
              offset_metadata_strategy: :current,
              reducer: nil,
              distribution: :consistent
            )
              @virtual_partitions ||= Config.new(
                active: !partitioner.nil?,
                max_partitions: max_partitions,
                partitioner: partitioner,
                offset_metadata_strategy: offset_metadata_strategy,
                # If no reducer provided, we use this one. It just runs a modulo on the sum of
                # a stringified version, providing fairly good distribution.
                reducer: reducer || ->(virtual_key) { virtual_key.to_s.sum % max_partitions },
                distribution: distribution
              )
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
