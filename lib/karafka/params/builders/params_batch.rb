# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      module ParamsBatch
        class << self
          def from_kafka_messages(kafka_messages, topic)
            params_array = kafka_messages.map! do |message|
              Karafka::Params::Builders::Params.from_kafka_message(message, topic)
            end

            Karafka::Params::ParamsBatch.new(params_array)
          end
        end
      end
    end
  end
end
