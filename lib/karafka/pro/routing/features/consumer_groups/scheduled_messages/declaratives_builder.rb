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
    module Routing
      module Features
        module ConsumerGroups
          class ScheduledMessages < Base
            # Declaratives (topic structure) extensions for scheduled messages.
            #
            # This is the topic-structure counterpart of the routing `scheduled_messages(name)`
            # call. In routing, `scheduled_messages(name)` wires the runtime/consumer behavior;
            # here, inside a `Karafka::App.declaratives.draw` block, `scheduled_messages(name)`
            # declares the broker-side topics (messages and states) with the Kafka-level
            # configuration the feature requires to operate correctly (tombstone compaction).
            #
            # `partitions` is declared here because the messages and states topics must always
            # share the same partition count (the scheduler ticks independently per partition), so
            # it is not a free per-topic knob. Replication factor is intentionally not set and falls
            # back to the declaratives defaults (`Karafka::App.declaratives.defaults`) or an explicit
            # user override, so the feature no longer hardcodes environment-specific values.
            module DeclarativesBuilder
              # Declares the scheduled messages topics structure.
              #
              # @param topic_name [String, false] name for the scheduled messages topic that is
              #   also used as a group identifier. `false` when the feature is not active, to keep
              #   API consistency with the routing `scheduled_messages(name)` call.
              # @param block [Proc] optional block yielded with the messages and states topic
              #   declarations so they can be reconfigured inline (e.g. replication factor).
              # @yieldparam messages_topic [Karafka::Declaratives::Topic] messages topic
              # @yieldparam states_topic [Karafka::Declaratives::Topic] states topic
              # @note Namespace for topics should include the divider as it is not automatically
              #   added.
              def scheduled_messages(topic_name = false, &block)
                return unless topic_name

                # We set it to 5 so we have enough space to handle more events. All related topics
                # should have the same partition count.
                default_partitions = 5
                msg_cfg = App.config.scheduled_messages
                states_topic_name = "#{topic_name}#{msg_cfg.states_postfix}"

                # This is a setup that should allow messages to be compacted fairly fast. Since
                # each dispatched message should be removed via tombstone, they do not have to be
                # present in the topic for too long.
                messages_topic = topic(topic_name) do
                  partitions default_partitions
                  config(
                    # Will ensure, that after tombstone is present, given scheduled message,
                    # that has been dispatched is removed by Kafka
                    "cleanup.policy": "compact",
                    # When 10% or more dispatches are done, compact data
                    "min.cleanable.dirty.ratio": 0.1,
                    # Frequent segment rotation to support intense compaction
                    "segment.ms": 3_600_000,
                    "delete.retention.ms": 3_600_000,
                    "segment.bytes": 52_428_800
                  )
                end

                # Holds states of scheduler per each of the partitions. Same partition count as the
                # messages topic since they tick independently per partition.
                states_topic = topic(states_topic_name) do
                  partitions default_partitions
                  config(
                    "cleanup.policy": "compact",
                    "min.cleanable.dirty.ratio": 0.1,
                    "segment.ms": 3_600_000,
                    "delete.retention.ms": 3_600_000,
                    "segment.bytes": 52_428_800
                  )
                end

                yield(messages_topic, states_topic) if block

                [messages_topic, states_topic]
              end
            end
          end
        end
      end
    end
  end
end
