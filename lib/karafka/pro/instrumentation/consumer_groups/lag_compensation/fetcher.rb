# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Instrumentation
      # Instrumentation components for consumer groups based operation
      module ConsumerGroups
        module LagCompensation
          # Fetches the offsets data needed for the lag compensation of given partitions, all
          # via the client own connection: no dedicated instances and no extra Kafka
          # connections are ever created. Committed offsets come in one batched query and the
          # end offset per partition via the watermark query.
          #
          # The end offset honors the consumer isolation level: under the default
          # read_committed it is the last stable offset, the same reference the native
          # librdkafka consumer lag derives from, so the compensated lags match the fetch-based
          # ones also on transactional topics.
          class Fetcher
            # @param client [Karafka::Connection::Client]
            # @param paused [Hash{String => Array<Integer>}] paused topics with partitions
            # @return [Hash{String => Hash{Integer => Hash}}] fetched data with `:end_offset`
            #   and `:committed_offset` per partition
            def call(client, paused)
              tpl = Rdkafka::Consumer::TopicPartitionList.new
              paused.each { |topic, partitions| tpl.add_topic(topic, partitions) }

              committed = client.committed(tpl)

              data = {}

              committed.to_h.each do |topic, partitions|
                partitions.each do |partition|
                  _, end_offset = client.query_watermark_offsets(topic, partition.partition)

                  (data[topic] ||= {})[partition.partition] = {
                    end_offset: end_offset,
                    committed_offset: partition.offset || -1
                  }
                end
              end

              data
            end
          end
        end
      end
    end
  end
end
