# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      # Builder for creating params batch instances
      module ParamsBatch
        class << self
          # Creates params batch with params inside based on the incoming messages
          # and the topic from which it comes
          # @param kafka_messages [Array<Kafka::FetchedMessage>] raw fetched messages
          # @param topic [Karafka::Routing::Topic] topic for which we're received messages
          # @return [Karafka::Params::ParamsBatch<Karafka::Params::Params>] batch with params
          def from_kafka_messages(kafka_messages, topic)
            params_array = kafka_messages.map do |message|
              Karafka::Params::Builders::Params.from_kafka_message(message, topic)
            end

            Karafka::Params::ParamsBatch.new(params_array).freeze
          end
        end
      end
    end
  end
end
