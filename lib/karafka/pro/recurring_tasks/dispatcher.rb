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
      class Dispatcher
        class << self
          # Snapshots to Kafka current schedule state
          def schedule
            produce(
              topics.schedules,
              'schedule',
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
              topics.schedules,
              task_id,
              serializer.command(name, task_id)
            )
          end

          # Dispatches the task execution log record
          # @param event [Karafka::Core::Monitoring::Event]
          def log(event)
            produce(
              topics.logs,
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
          # @param payload [Hash] hash with payload
          # @param task_id [String]
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
