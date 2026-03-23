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
    module Processing
      module VirtualPartitions
        module Distributors
          # Balanced distributor that groups messages by partition key
          # and processes larger groups first while maintaining message order within groups
          class Balanced < Base
            # Distributes messages to virtual partitions ensuring balanced load across workers
            # by grouping messages by partition key and assigning larger groups first
            # @param messages [Array<Karafka::Messages::Message>]
            # @return [Hash{Integer => Array<Karafka::Messages::Message>}] hash with group ids as
            #   keys and message groups as values
            def call(messages)
              # Group messages by partition key
              key_groupings = messages.group_by { |msg| config.partitioner.call(msg) }

              worker_loads = Array.new(config.max_partitions, 0)
              worker_assignments = Array.new(config.max_partitions) { [] }

              # Sort keys by workload in descending order
              sorted_keys = key_groupings.keys.sort_by { |key| -key_groupings[key].size }

              # Assign each key to the worker with the least current load
              sorted_keys.each do |key|
                # Find worker with minimum current load
                min_load_worker = worker_loads.each_with_index.min_by { |load, _| load }[1]
                messages = key_groupings[key]

                # Assign this key to that worker
                worker_assignments[min_load_worker] += messages
                worker_loads[min_load_worker] += messages.size
              end

              # Combine messages for each worker and sort by offset
              worker_assignments
                .each_with_index
                .reject { |group_messages, _| group_messages.empty? }
                .map! { |group_messages, index| [index, group_messages.sort_by!(&:offset)] }
                .to_h
            end
          end
        end
      end
    end
  end
end
