# frozen_string_literal: true

# Karafka should support configuring the producer via a block during setup.
# This allows users to customize producer settings without manually creating a producer instance.

setup_karafka do |config|
  config.kafka = { "bootstrap.servers": "localhost:9092" }

  config.producer do |producer_config|
    producer_config.kafka[:"compression.type"] = "snappy"
    producer_config.kafka[:"linger.ms"] = 10
    producer_config.max_wait_timeout = 30_000
  end
end

# Verify the producer was configured with our custom settings
producer = Karafka::App.config.producer

assert_equal "snappy", producer.config.kafka[:"compression.type"]
assert_equal 10, producer.config.kafka[:"linger.ms"]
assert_equal 30_000, producer.config.max_wait_timeout
