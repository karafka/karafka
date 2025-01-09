# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Converts schedule command and log details into data we can dispatch to Kafka.
      class Serializer
        # Current recurring tasks related schema structure
        SCHEMA_VERSION = '1.0'

        # @param schedule [Karafka::Pro::RecurringTasks::Schedule] schedule to serialize
        # @return [String] serialized and compressed current schedule data with its tasks and their
        #   current state.
        def schedule(schedule)
          tasks = {}

          schedule.each do |task|
            tasks[task.id] = {
              id: task.id,
              cron: task.cron.original,
              previous_time: task.previous_time.to_i,
              next_time: task.next_time.to_i,
              enabled: task.enabled?
            }
          end

          data = {
            schema_version: SCHEMA_VERSION,
            schedule_version: schedule.version,
            dispatched_at: Time.now.to_f,
            type: 'schedule',
            tasks: tasks
          }

          compress(
            serialize(data)
          )
        end

        # @param command_name [String] command name
        # @param task_id [String] task id or '*' to match all.
        # @return [String] serialized and compressed command data
        def command(command_name, task_id)
          data = {
            schema_version: SCHEMA_VERSION,
            schedule_version: ::Karafka::Pro::RecurringTasks.schedule.version,
            dispatched_at: Time.now.to_f,
            type: 'command',
            command: {
              name: command_name
            },
            task: {
              id: task_id
            }
          }

          compress(
            serialize(data)
          )
        end

        # @param event [Karafka::Core::Monitoring::Event] recurring task dispatch event
        # @return [String] serialized and compressed event log data
        def log(event)
          task = event[:task]

          data = {
            schema_version: SCHEMA_VERSION,
            schedule_version: ::Karafka::Pro::RecurringTasks.schedule.version,
            dispatched_at: Time.now.to_f,
            type: 'log',
            task: {
              id: task.id,
              time_taken: event.payload[:time] || -1,
              result: event.payload.key?(:error) ? 'failure' : 'success'
            }
          }

          compress(
            serialize(data)
          )
        end

        private

        # @param hash [Hash] hash to cast to json
        # @return [String] json hash
        def serialize(hash)
          hash.to_json
        end

        # Compresses the provided data
        #
        # @param data [String] data to compress
        # @return [String] compressed data
        def compress(data)
          Zlib::Deflate.deflate(data)
        end
      end
    end
  end
end
