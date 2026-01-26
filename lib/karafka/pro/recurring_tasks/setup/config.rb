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
    module RecurringTasks
      # Setup and config related recurring tasks components
      module Setup
        # Config for recurring tasks
        class Config
          extend Karafka::Core::Configurable

          setting(:consumer_class, default: Consumer)
          setting(:deserializer, default: Deserializer.new)
          setting(:group_id, default: "karafka_recurring_tasks")
          # By default we will run the scheduling every 15 seconds since we provide a minute-based
          # precision
          setting(:interval, default: 15_000)
          # Should we log the executions. If true (default) with each cron execution, there will
          # be a special message published. Useful for debugging.
          setting(:logging, default: true)

          # Producer to be used by the recurring tasks.
          # By default it is a `Karafka.producer`, however it may be overwritten if we want to use
          # a separate instance in case of heavy usage of the  transactional producer, etc.
          setting(
            :producer,
            constructor: -> { Karafka.producer },
            lazy: true
          )

          setting(:topics) do
            setting(:schedules) do
              setting(:name, default: "karafka_recurring_tasks_schedules")
            end

            setting(:logs) do
              setting(:name, default: "karafka_recurring_tasks_logs")
            end
          end

          configure
        end
      end
    end
  end
end
