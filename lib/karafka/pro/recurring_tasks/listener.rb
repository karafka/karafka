# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
          return unless event[:type] == 'recurring_tasks.task.execute.error'

          Dispatcher.log(event)
        end
      end
    end
  end
end
