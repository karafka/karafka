# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Represents a single recurring task that can be executed when the time comes.
      # Tasks should be lightweight. Anything heavy should be executed by scheduling appropriate
      # jobs here.
      class Task
        include Helpers::ConfigImporter.new(
          monitor: %i[monitor]
        )

        # @return [String] this task id
        attr_reader :id

        # @return [Fugit::Cron] cron from parsing the raw cron expression
        attr_reader :cron

        # Allows for update of previous time when restoring the materialized state
        attr_accessor :previous_time

        # @param id [String] unique id. If re-used between versions, will replace older occurrence.
        # @param cron [String] cron expression matching this task expected execution times.
        # @param previous_time [Integer, Time] previous time this task was executed. 0 if never.
        # @param enabled [Boolean] should this task be enabled. Users may disable given task
        #   temporarily, this is why we need to know that.
        # @param block [Proc] code to execute.
        def initialize(id:, cron:, previous_time: 0, enabled: true, &block)
          @id = id
          @cron = ::Fugit::Cron.do_parse(cron)
          @previous_time = previous_time
          @start_time = Time.now
          @executable = block
          @enabled = enabled
          @trigger = false
          @changed = false
        end

        # @return [Boolean] true if anything in the task has changed and we should persist it
        def changed?
          @changed
        end

        # Disables this task execution indefinitely
        def disable
          touch
          @enabled = false
        end

        # Enables back this task
        def enable
          touch
          @enabled = true
        end

        # @return [Boolean] is this an executable task
        def enabled?
          @enabled
        end

        # Triggers the execution of this task at the earliest opportunity
        def trigger
          touch
          @trigger = true
        end

        # @return [EtOrbi::EoTime] next execution time
        def next_time
          @cron.next_time(@previous_time.to_i.zero? ? @start_time : @previous_time)
        end

        # @return [Boolean] should we execute this task at this moment in time
        def call?
          return true if @trigger
          return false unless enabled?

          # Ensure the job is only due if current_time is strictly after the next_time
          # Please note that we can only compare eorbi against time and not the other way around
          next_time <= Time.now
        end

        # Executes the given task and publishes appropriate notification bus events.
        def call
          monitor.instrument(
            'recurring_tasks.task.executed',
            task: self
          ) do
            # We check for presence of the `@executable` because user can define cron schedule
            # without the code block
            return unless @executable

            execute
          end
        rescue StandardError => e
          monitor.instrument(
            'error.occurred',
            caller: self,
            error: e,
            task: self,
            type: 'recurring_tasks.task.execute.error'
          )
        ensure
          @trigger = false
          @previous_time = Time.now
        end

        # Runs the executable block without any instrumentation or error handling. Useful for
        # debugging and testing
        def execute
          @executable.call
        end

        # Removes the changes indicator flag
        def clear
          @changed = false
        end

        # @return [Hash] hash version of the task. Used for contract validation.
        def to_h
          {
            id: id,
            cron: @cron.original,
            previous_time: previous_time,
            next_time: next_time,
            changed: changed?,
            enabled: enabled?
          }
        end

        private

        # Marks the task as changed
        def touch
          @changed = true
        end
      end
    end
  end
end
