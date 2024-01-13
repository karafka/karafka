# frozen_string_literal: true

# Multiplexing details should be validated

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group :test do
      multiplexing(max: 10, min: 11)

      topic DT.topics[0] do
        consumer Consumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
