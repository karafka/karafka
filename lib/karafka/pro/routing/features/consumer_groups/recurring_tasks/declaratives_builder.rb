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
          class RecurringTasks < Base
            # Declaratives (topic structure) extensions for recurring tasks.
            #
            # This is the topic-structure counterpart of the routing `recurring_tasks(true)` call.
            # In routing, `recurring_tasks(true)` wires the runtime/consumer behavior; here, inside
            # a `Karafka::App.declaratives.draw` block, `recurring_tasks(true)` declares the
            # broker-side topics (schedules and logs) with the Kafka-level configuration the feature
            # requires to operate correctly (compaction and retention).
            #
            # Only the functional configuration is declared. Infrastructure sizing
            # (`replication_factor`, and `partitions` beyond the single-partition default) is left
            # to the declaratives defaults (`Karafka::App.declaratives.defaults`) or to an explicit
            # user override, so the feature no longer hardcodes environment-specific values.
            module DeclarativesBuilder
              # Declares the recurring tasks topics structure.
              #
              # @param active [Boolean] should the recurring tasks topics be declared. We use a
              #   boolean flag to keep API consistency with the routing `recurring_tasks(true)`
              #   call so the same invocation reads the same way in both contexts.
              # @param block [Proc] optional block yielded with the schedules and logs topic
              #   declarations so they can be reconfigured inline (e.g. replication factor).
              # @yieldparam schedules_topic [Karafka::Declaratives::Topic] schedules topic
              # @yieldparam logs_topic [Karafka::Declaratives::Topic] logs topic
              def recurring_tasks(active = true, &block)
                return unless active

                topics_cfg = App.config.recurring_tasks.topics

                # Keep older data for a day and compact to the last state available
                schedules_topic = topic(topics_cfg.schedules.name) do
                  config(
                    "cleanup.policy": "compact,delete",
                    "retention.ms": 86_400_000
                  )
                end

                # Keep cron logs of executions for a week and after that remove. A week should be
                # enough and should not produce too much data.
                logs_topic = topic(topics_cfg.logs.name) do
                  config(
                    "cleanup.policy": "delete",
                    "retention.ms": 604_800_000
                  )
                end

                yield(schedules_topic, logs_topic) if block

                [schedules_topic, logs_topic]
              end
            end
          end
        end
      end
    end
  end
end
