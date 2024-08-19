# frozen_string_literal: true

module Karafka
  module Pro
    module RecurringTasks
      class Executor
        COMMANDS = %w[
          disable
          enable
          trigger
        ].freeze

        private_constant :COMMANDS

        def initialize
          @replaying = true
          @incompatible = false
          @catchup_commands = []
          @catchup_state = nil
          @matcher = Matcher.new
        end

        def replaying?
          @replaying
        end

        def incompatible?
          @incompatible
        end

        def apply_command(command_hash)
          command = command_hash[:command][:name]

          raise(Karafka::Errors::UnsupportedCaseError, command) unless COMMANDS.include?(command)

          schedule.each do |task|
            next unless @matcher.matches?(task, command_hash)

            task.public_send(command)
          end
        end

        def update_state(state_hash)
          @catchup_state = state_hash
        end

        def replay
          # Ensure replaying happens only once
          return unless @replaying

          @replaying = false

          # When there is nothing to replay and synchronize, we can just save the state and
          # proceed
          if @catchup_commands.empty? && @catchup_state.nil?
            snapshot

            return
          end

          # If the schedule version we have in Kafka is higher than ours, we cannot proceed
          # This prevents us from applying older changes to a new schedule
          if @catchup_state[:schedule_version] > schedule.version
            @incompatible = true

            return
          end

          # Now we can synchronize the
          schedule.each do |task|
            stored_task = @catchup_state[:tasks][task.id.to_sym]

            next unless stored_task

            stored_previous_time = stored_task[:previous_time]
            task.previous_time = stored_previous_time.zero? ? 0 : Time.at(stored_previous_time)
            stored_task[:enabled] ? task.enable : task.disable
          end

          @catchup_commands.each do |cmd|
            apply_command(cmd)
          end

          snapshot

          @catchup_state = nil
          @catchup_commands = []
        end

        def execute
          changed = false

          schedule.each do |task|
            changed = true if task.changed?

            unless task.execute?
              task.clear

              next
            end

            changed = true
            task.execute
          end

          snapshot if changed
        end

        private

        def schedule
          ::Karafka::Pro::RecurringTasks.schedule
        end

        def snapshot
          Dispatcher.schedule
        end
      end
    end
  end
end
