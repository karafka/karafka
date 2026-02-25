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
      # Listener we use to track execution of recurring tasks and publish those events into the
      # recurring tasks log table
      class Listener
        # @param event [Karafka::Core::Monitoring::Event] task execution event
        def on_recurring_tasks_task_executed(event)
          Dispatcher.log(event)
        end

        # @param event [Karafka::Core::Monitoring::Event] error that occurred
        # @note We do nothing with other errors. We only want to log and dispatch information about
        #   the recurring tasks errors. The general Web UI error tracking may also work but those
        #   are independent. It is not to replace the Web UI tracking but to just log failed
        #   executions in the same way as successful but just with the failure as an outcome.
        def on_error_occurred(event)
          return unless event[:type] == "recurring_tasks.task.execute.error"

          Dispatcher.log(event)
        end
      end
    end
  end
end
