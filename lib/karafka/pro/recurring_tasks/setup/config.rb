# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Setup and config related recurring tasks components
      module Setup
        # Config for recurring tasks
        class Config
          extend ::Karafka::Core::Configurable

          setting(:consumer_class, default: Consumer)
          setting(:deserializer, default: Deserializer.new)
          setting(:group_id, default: 'karafka_recurring_tasks')
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
            constructor: -> { ::Karafka.producer },
            lazy: true
          )

          setting(:topics) do
            setting(:schedules) do
              setting(:name, default: 'karafka_recurring_tasks_schedules')
            end

            setting(:logs) do
              setting(:name, default: 'karafka_recurring_tasks_logs')
            end
          end

          configure
        end
      end
    end
  end
end
