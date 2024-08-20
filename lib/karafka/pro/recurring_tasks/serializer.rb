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
          time = event[:time]

          data = {
            schema_version: SCHEMA_VERSION,
            schedule_version: ::Karafka::Pro::RecurringTasks.schedule.version,
            dispatched_at: Time.now.to_f,
            type: 'log',
            task: {
              id: task.id,
              time_taken: time,
              previous_time: task.previous_time.to_i,
              next_time: task.next_time.to_i
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
