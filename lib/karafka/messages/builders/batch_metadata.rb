# frozen_string_literal: true

module Karafka
  module Messages
    module Builders
      # Builder for creating batch metadata object based on the batch informations.
      module BatchMetadata
        class << self
          # Creates metadata based on the kafka batch data.
          #
          # @param kafka_batch [Array<Rdkafka::Consumer::Message>] raw fetched messages
          # @param topic [Karafka::Routing::Topic] topic for which we've fetched the batch
          # @param scheduled_at [Time] moment when the batch was scheduled for processing
          # @return [Karafka::Messages::BatchMetadata] batch metadata object
          # @note Regarding the time lags: we can use the current time here, as batch metadata is
          #   created in the worker. So whenever this is being built, it means that the processing
          #   of this batch has already started.
          def call(kafka_batch, topic, scheduled_at)
            now = Time.now

            Karafka::Messages::BatchMetadata.new(
              size: kafka_batch.count,
              first_offset: kafka_batch.first.offset,
              last_offset: kafka_batch.last.offset,
              deserializer: topic.deserializer,
              partition: kafka_batch[0].partition,
              topic: topic.name,
              scheduled_at: scheduled_at,
              # This lag describes how long did it take for a message to be consumed from the
              # moment it was created
              consumption_lag: time_distance_in_ms(now, kafka_batch.last.timestamp),
              # This lag describes how long did a batch have to wait before it was picked up by
              # one of the workers
              processing_lag: time_distance_in_ms(now, scheduled_at)
            ).freeze
          end

          private

          # Computes time distance in between two times in ms
          #
          # @param time1 [Time]
          # @param time2 [Time]
          # @return [Integer] distance in between two times in ms
          def time_distance_in_ms(time1, time2)
            ((time1 - time2) * 1_000).round
          end
        end
      end
    end
  end
end
