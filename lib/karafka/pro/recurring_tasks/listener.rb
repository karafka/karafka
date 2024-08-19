# frozen_string_literal: true

module Karafka
  module Pro
    module RecurringTasks
      # Listener we use to track execution of recurring tasks and publish those events into the
      # recurring tasks log table
      class Listener
        # @param [Karafka::Core::Monitoring::Event] task execution event
        def on_recurring_tasks_task_executed(event)
          Dispatcher.log(event)
        end
      end
    end
  end
end
