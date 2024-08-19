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
      end
    end
  end
end
