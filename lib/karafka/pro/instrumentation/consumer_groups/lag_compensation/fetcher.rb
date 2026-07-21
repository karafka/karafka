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
          # Fetches the end offsets of given partitions via the client own connection: no
          # dedicated instances and no extra Kafka connections are ever created.
          #
          # All partitions are resolved with one batched request that librdkafka fans out to the
          # involved partition leaders internally, so the cost does not grow with the number of
          # paused partitions.
          #
          # End offsets are the only thing the compensation needs from the broker: committed
          # and stored offsets of paused partitions are maintained by the client commits (not
          # by fetches), so their statistics values stay accurate while paused and lags can be
          # derived from them at compensation time.
          #
          # The consumer isolation level is forwarded to the query, so on topics without in-flight
          # transactions the end offset matches the reference the native consumer lag derives from.
          #
          # Known edge case (transactional topics): the batched `ListOffsets` this uses resolves
          # `:latest` to the high watermark regardless of the forwarded isolation level, unlike the
          # per-partition `query_watermark_offsets` it replaced, which returned the last stable
          # offset for a read_committed consumer. So while a transaction is IN FLIGHT on a paused
          # partition, the compensated end offset (and the lag derived from it) reflects the high
          # watermark and can overstate the read_committed lag by the number of uncommitted
          # messages. It self-corrects once the transaction commits or aborts and the last stable
          # offset advances. Non-transactional topics are unaffected (LSO == HWM there).
          class Fetcher
            # @param client [Karafka::Connection::Client]
            # @param paused [Hash{String => Array<Integer>}] paused topics with partitions
            # @return [Hash{String => Hash{Integer => Integer}}] end offsets of the requested
            #   partitions
            def call(client, paused)
              request = paused.transform_values do |partitions|
                partitions.map { |partition| { partition: partition, offset: :latest } }
              end

              return {} if request.empty?

              # Auto-initializes the per-topic partitions hash on first access, same idiom as
              # the refresher state. Only ever written to and iterated here, never read by a
              # missing key, so the default block cannot insert a spurious entry.
              data = Hash.new { |topics, topic| topics[topic] = {} }

              client.read_partition_offsets(request).each do |result|
                data[result[:topic]][result[:partition]] = result[:offset]
              end

              data
            end
          end
        end
      end
    end
  end
end
