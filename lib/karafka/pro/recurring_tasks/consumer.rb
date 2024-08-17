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
      # Consumer responsible for management of the recurring tasks and their execution
      class Consumer < ::Karafka::BaseConsumer
        # Loads the schedules and manages the commands
        def consume
          # Since we can have eofed alongside messages during recovery we call it if needed
          eofed if eofed?
        end

        # Finalizes the schedule recovery (if needed)
        def eofed; end

        # Runs schedules in the fixed intervals
        def tick; end

        private

        # Use our producer that could be redefined only for the recurring tasks
        def producer
          ::Karafka::App.config.recurring_tasks.producer
        end
      end
    end
  end
end
