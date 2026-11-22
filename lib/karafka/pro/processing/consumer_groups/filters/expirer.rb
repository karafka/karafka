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
    module Processing
      module ConsumerGroups
        module Filters
          # Expirer for removing too old messages.
          # It never moves offsets in any way and does not impact the processing flow. It always
          # runs the `Actions.skip` action.
          class Expirer < Base
            include Helpers::ConfigImporter.new(
              monitor: %i[monitor]
            )

            # @param ttl [Integer] maximum age of a message (in ms)
            # @param topic [Karafka::Routing::Topic] topic for which we filter
            # @param partition [Integer] partition for which we filter
            def initialize(ttl, topic, partition)
              super()

              @ttl = ttl
              @topic = topic
              @partition = partition
            end

            # Removes too old messages and instruments `filtering.expired` when any were removed
            #
            # @param messages [Array<Karafka::Messages::Message>]
            def apply!(messages)
              @applied = false
              count = 0
              first = nil
              last = nil

              # Time on message is in seconds with ms precision, so we need to convert the ttl that
              # is in ms to this format
              border = Time.now.utc - (@ttl / 1_000.to_f)

              messages.delete_if do |message|
                too_old = message.timestamp < border

                if too_old
                  first ||= message
                  last = message
                  count += 1
                end

                too_old
              end

              return if count.zero?

              @applied = true

              monitor.instrument(
                "filtering.expired",
                caller: self,
                topic: @topic.name,
                partition: @partition,
                subscription_group: @topic.subscription_group,
                count: count,
                first_offset: first.offset,
                last_offset: last.offset,
                ttl: @ttl
              )
            end

            # @return [nil] this filter does not deal with timeouts
            def timeout
              nil
            end
          end
        end
      end
    end
  end
end
