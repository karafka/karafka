# frozen_string_literal: true

module Karafka
  module Params
    module Builders
      # Builder for creating metadata object based on the message or batch informations
      module Metadata
        class << self
          def from_kafka_batch(_kafka_batch, _topic)
            Karafka::Params::Metadata.new
          end

          def from_kafka_message(_kafka_message, _topic)
            Karafka::Params::Metadata.new
          end
        end
      end
    end
  end
end
