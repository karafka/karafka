# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
