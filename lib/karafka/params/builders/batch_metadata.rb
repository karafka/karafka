# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      # Builder for creating batch metadata object based on the batch informations
      module BatchMetadata
        class << self
          # Creates metadata based on the kafka batch data
          # @param kafka_batch [Kafka::FetchedBatch] kafka batch details
          # @param topic [Karafka::Routing::Topic] topic for which we've fetched the batch
          # @return [Karafka::Params::BatchMetadata] batch metadata object
          def from_kafka_batch(kafka_batch, topic)
            Karafka::Params::BatchMetadata.new(
              batch_size: kafka_batch.messages.count,
              first_offset: kafka_batch.first_offset,
              highwater_mark_offset: kafka_batch.highwater_mark_offset,
              unknown_last_offset: kafka_batch.unknown_last_offset?,
              last_offset: kafka_batch.last_offset,
              offset_lag: kafka_batch.offset_lag,
              deserializer: topic.deserializer,
              partition: kafka_batch.partition,
              topic: topic.name
            ).freeze
          end
        end
      end
    end
  end
end
