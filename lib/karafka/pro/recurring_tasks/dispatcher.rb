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
      # Dispatches appropriate recurring tasks related messages to expected topics
      class Dispatcher
        extend Helpers::ConfigImporter.new(
          topics: %i[recurring_tasks topics]
        )

        class << self
          # Snapshots to Kafka current schedule state
          def schedule
            produce(
              topics.schedules.name,
              "state:schedule",
              serializer.schedule(::Karafka::Pro::RecurringTasks.schedule)
            )
          end

          # Dispatches the command request
          #
          # @param name [String, Symbol] name of the command we want to deal with in the process
          # @param task_id [String] id of the process. We use name instead of id only
          #   because in the web ui we work with the full name and it is easier. Since
          def command(name, task_id)
            produce(
              topics.schedules.name,
              "command:#{name}:#{task_id}",
              serializer.command(name, task_id)
            )
          end

          # Dispatches the task execution log record
          # @param event [Karafka::Core::Monitoring::Event]
          def log(event)
            produce(
              topics.logs.name,
              event[:task].id,
              serializer.log(event)
            )
          end

          private

          # @return [::WaterDrop::Producer] web ui producer
          # @note We do not fetch it via the ConfigImporter not to cache it so we can re-use it
          #   if needed
          def producer
            Karafka::App.config.recurring_tasks.producer
          end

          # @return [Serializer]
          def serializer
            Serializer.new
          end

          # Converts payload to json, compresses it and dispatches to Kafka
          #
          # @param topic [String] target topic
          # @param key [String]
          # @param payload [Hash] hash with payload
          def produce(topic, key, payload)
            producer.produce_async(
              topic: topic,
              key: key,
              partition: 0,
              payload: payload,
              headers: { "zlib" => "true" }
            )
          end
        end
      end
    end
  end
end
