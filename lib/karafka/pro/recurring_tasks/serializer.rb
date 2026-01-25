# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module RecurringTasks
      # Converts schedule command and log details into data we can dispatch to Kafka.
      class Serializer
        # Current recurring tasks related schema structure
        SCHEMA_VERSION = "1.0"

        # Serializes and compresses the schedule with all its tasks and their execution state
        # @param schedule [Karafka::Pro::RecurringTasks::Schedule]
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
            type: "schedule",
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
            schedule_version: Karafka::Pro::RecurringTasks.schedule.version,
            dispatched_at: Time.now.to_f,
            type: "command",
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
            schedule_version: Karafka::Pro::RecurringTasks.schedule.version,
            dispatched_at: Time.now.to_f,
            type: "log",
            task: {
              id: task.id,
              time_taken: event.payload[:time] || -1,
              result: event.payload.key?(:error) ? "failure" : "success"
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

        # Compresses the provided data using Zlib deflate algorithm
        #
        # @param data [String]
        # @return [String] compressed data
        def compress(data)
          Zlib::Deflate.deflate(data)
        end
      end
    end
  end
end
