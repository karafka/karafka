# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Executor is responsible for management of the state of recurring tasks schedule and
      # is the heart of recurring tasks. It coordinates the replaying process as well as
      # tracking of data on changes.
      class Executor
        # Task commands we support and that can be triggered on tasks (if matched)
        COMMANDS = %w[
          disable
          enable
          trigger
        ].freeze

        def initialize
          @replaying = true
          @incompatible = false
          @catchup_commands = []
          @catchup_schedule = nil
          @matcher = Matcher.new
        end

        # @return [Boolean] are we in the replaying phase or not (false means, regular operations)
        def replaying?
          @replaying
        end

        # @return [Boolean] Is the current process schedule incompatible (older) than the one
        #   that we have in memory
        def incompatible?
          @incompatible
        end

        # Applies given command to task (or many tasks) by running the command on tasks that match
        # @param command_hash [Hash] deserialized command data
        def apply_command(command_hash)
          cmd_name = command_hash[:command][:name]

          raise(Karafka::Errors::UnsupportedCaseError, cmd_name) unless COMMANDS.include?(cmd_name)

          schedule.each do |task|
            next unless @matcher.matches?(task, command_hash)

            task.public_send(cmd_name)
          end
        end

        # Updates the catchup state
        # @param schedule_hash [Hash] deserialized schedule hash hash
        def update_state(schedule_hash)
          @catchup_schedule = schedule_hash
        end

        # Once all previous data is accumulated runs the catchup process to establish current
        # state of the recurring tasks schedule execution.
        #
        # It includes applying any requested commands as well as synchronizing execution details
        # for existing schedule and making sure all is loaded correctly.
        def replay
          # Ensure replaying happens only once
          return unless @replaying

          @replaying = false

          # When there is nothing to replay and synchronize, we can just save the state and
          # proceed
          if @catchup_commands.empty? && @catchup_schedule.nil?
            snapshot

            return
          end

          # If the schedule version we have in Kafka is higher than ours, we cannot proceed
          # This prevents us from applying older changes to a new schedule
          if @catchup_schedule[:schedule_version] > schedule.version
            @incompatible = true

            return
          end

          # Now we can synchronize the in-memory state based on the last state stored in Kafka
          schedule.each do |task|
            stored_task = @catchup_schedule[:tasks][task.id.to_sym]

            next unless stored_task

            stored_previous_time = stored_task[:previous_time]
            task.previous_time = stored_previous_time.zero? ? 0 : Time.at(stored_previous_time)

            stored_task[:enabled] ? task.enable : task.disable
          end

          @catchup_commands.each do |cmd|
            apply_command(cmd)
          end

          # We make sure to save in Kafka once more once everything is up to date
          snapshot

          @catchup_schedule = nil
          @catchup_commands = []
        end

        # Run all tasks that should run at a given time and if any tasks were changed in any way
        # or executed, stores the most recent state back to Kafka
        def call
          changed = false

          schedule.each do |task|
            changed = true if task.changed?

            unless task.call?
              task.clear

              next
            end

            changed = true
            task.call
          end

          snapshot if changed
        end

        private

        # @return [Karafka::Pro::RecurringTasks::Schedule] current in-memory schedule
        def schedule
          ::Karafka::Pro::RecurringTasks.schedule
        end

        # Dispatches the current schedule state to Kafka
        def snapshot
          Dispatcher.schedule
        end
      end
    end
  end
end
