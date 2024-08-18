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
        def initialize(*args)
          super
          @recovering = true
          @any_consumed = false
          @in_recovery = true
          @catchup_commands = []
          @catchup_states = []
        end

        # Loads the schedules and manages the commands
        def consume
          if @incompatible
            raise Errors::IncompatibleScheduleError
          end

          @any_consumed = true

          if @in_recovery
            messages.each do |message|
              case message.payload[:type]
              when 'schedule'
                @catchup_states << message.payload
              when 'command'
                @catchup_commands << message.payload
              else
                #p message.payload
                #raise
              end
            end
          else
            messages.each do |message|
              case message.payload[:type]
              when 'schedule'
                # We cannot mark as consumed on the previous message if it is first message
                next if message.offset.zero?

                mark_as_consumed Karafka::Messages::Seek.new(
                  topic: topic.name,
                  partition: partition,
                  offset: message.offset - 1
                )
              when 'command'
                # not supported at the moment
              else
                raise
              end
            end

            tick
          end

          # Since we can have eofed alongside messages during recovery we call it if needed
          eofed if eofed?
        end

        # Finalizes the schedule recovery (if needed)
        def eofed
          # This can only happen when there is nothing in the
          if !@any_consumed && @in_recovery
            snapshot
          end

          if @in_recovery && @any_consumed
            most_recent = @catchup_states.last

            if most_recent[:schedule_version] > current_schedule.version
              @incompatible = true
              raise Errors::IncompatibleScheduleError
            end

            current_schedule.each do |task|
              stored_task = most_recent[:tasks][task.id.to_sym]

              next unless stored_task

              task.previous_time = stored_task[:previous_time].zero? ? 0 : Time.at(stored_task[:previous_time])

              stored_task[:enabled] ? task.enable : task.disable
            end

            snapshot

            @catchup_states = nil
            @catchup_commands = nil
          end

          @in_recovery = false
        end

        # Runs schedules in the fixed intervals
        def tick
          if @incompatible
            if messages.empty?
              raise Errors::IncompatibleScheduleError
            else
              return seek(messages.last.offset - 1)
            end
          end

          changed = false

          return unless current_schedule

          current_schedule.each do |task|
            next unless task.execute?

            changed = true

            task.execute
          end

          snapshot if changed
        end

        private

        # Use our producer that could be redefined only for the recurring tasks
        def producer
          ::Karafka::App.config.recurring_tasks.producer
        end

        # @return [Executor] cron jobs executor that is responsible for managing and running them
        def executor
          @executor ||= Executor.new
        end

        def current_schedule
          ::Karafka::Pro::RecurringTasks.current_schedule
        end

        def snapshot
          # If no schedule defined, do nothing
          return unless current_schedule

          producer.produce_async(
            topic: topic.name,
            partition: 0,
            key: 'schedule',
            payload: Serializer.new.call(current_schedule)
          )
        end
      end
    end
  end
end
