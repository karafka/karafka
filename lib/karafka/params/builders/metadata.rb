# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      # Builder for creating metadata object based on the message or batch informations
      # @note We have 2 ways of creating metadata based on the way ruby-kafka operates
      module Metadata
        class << self
          # Creates metadata based on the kafka batch data
          # @param _kafka_batch [Kafka::FetchedBatch] kafka batch details
          # @param _topic [Karafka::Routing::Topic] topic for which we've fetched the batch
          # @return [Karafka::Params::Metadata] metadata object
          def from_kafka_batch(_kafka_batch, _topic)
            Karafka::Params::Metadata.new
          end

          # Creates metadata based on a single kafka message (for a single mode)
          # @param _kafka_message [Kafka::FetchedMessage] message received from kafka
          # @param _topic [Karafka::Routing::Topic] topic for which we've fetched the batch
          # @return [Karafka::Params::Metadata] metadata object
          def from_kafka_message(_kafka_message, _topic)
            Karafka::Params::Metadata.new
          end
        end
      end
    end
  end
end
