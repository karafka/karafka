# frozen_string_literal: true

# Karafka should work correctly when no producer configuration block is provided.
# The default producer should be created with standard settings.

setup_karafka

# Verify a default producer was created
producer = Karafka::App.config.producer

assert producer.is_a?(WaterDrop::Producer)
# Should have inherited kafka settings from config
assert_equal "127.0.0.1:9092", producer.config.kafka[:"bootstrap.servers"]
