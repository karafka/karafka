# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      # Builder for creating metadata object based on the message or batch informations
      # @note We have 2 ways of creating metadata based on the way ruby-kafka operates
      module Metadata
        class << self
          # Creates metadata based on the kafka batch data
          # @param kafka_batch [Kafka::FetchedBatch] kafka batch details
          # @param topic [Karafka::Routing::Topic] topic for which we've fetched the batch
          # @return [Karafka::Params::Metadata] metadata object
          def from_kafka_batch(kafka_batch, topic)
            Karafka::Params::Metadata
              .new
              .merge!(
                'batch_size' => kafka_batch.messages.count,
                'first_offset' => kafka_batch.first_offset,
                'highwater_mark_offset' => kafka_batch.highwater_mark_offset,
                'last_offset' => kafka_batch.last_offset,
                'offset_lag' => kafka_batch.offset_lag,
                'deserializer' => topic.deserializer,
                'partition' => kafka_batch.partition,
                'topic' => kafka_batch.topic,
                'unknown_last_offset' => kafka_batch.unknown_last_offset?
              )
          end
        end
      end
    end
  end
end
