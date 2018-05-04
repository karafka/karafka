# frozen_string_literal: true

module Karafka
  module Connection
    # Builder used to construct Kafka client
    module Builder
      class << self
        # Builds a Kafka::Cient instance that we use to work with Kafka cluster
        # @return [::Kafka::Client] returns a Kafka client
        def call
          Kafka.new(*ApiAdapter.client)
        end
      end
    end
  end
end
