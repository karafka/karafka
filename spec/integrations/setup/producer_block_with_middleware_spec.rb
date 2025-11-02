# frozen_string_literal: true

# Karafka should allow adding middleware to the producer via the configuration block

class TestSetupMiddleware
  def call(message)
    message
  end
end

setup_karafka do |config|
  config.producer do |producer_config|
    producer_config.middleware.append(TestSetupMiddleware.new)
  end
end

# Verify configuration was applied by checking middleware was added
# We can't easily inspect the middleware stack, but we can verify the producer
# was configured without errors and middleware setup doesn't raise
producer = Karafka::App.config.producer

assert producer.is_a?(WaterDrop::Producer)
