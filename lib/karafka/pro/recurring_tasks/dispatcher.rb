# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Dispatches appropriate recurring tasks related messages to expected topics
      class Dispatcher
        class << self
          # Snapshots to Kafka current schedule state
          def schedule
            produce(
              topics.schedules.name,
              'state:schedule',
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
          def producer
            ::Karafka::App.config.recurring_tasks.producer
          end

          # @return [String] consumers commands topic
          def topics
            ::Karafka::App.config.recurring_tasks.topics
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
              headers: { 'zlib' => 'true' }
            )
          end
        end
      end
    end
  end
end
