# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      module Metadata
        class << self
          def from_kafka_batch(kafka_batch, topic)
            Karafka::Params::Metadata.new
          end

          def from_kafka_message(kafka_message, topic)
            Karafka::Params::Metadata.new
          end
        end
      end
    end
  end
end
