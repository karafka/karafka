# frozen_string_literal: true

# When config.producer is called without arguments during setup, it should act as a reader
# and return the current producer value, not reset it to nil.
#
# Before the fix, calling config.producer without arguments inside the setup block would
# execute `__getobj__.producer = nil`, destroying any previously assigned custom producer.
# The `configure_components` method would then see nil and create a default producer via `||=`,
# silently losing the user's custom producer.

custom_producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
end

producer_read_during_setup = nil

Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }

  # Assign a custom producer (goes through SimpleDelegator to real config's producer=)
  config.producer = custom_producer

  # Read it back - this should return the custom producer, not reset it to nil
  producer_read_during_setup = config.producer
end

# The read during setup should have returned the custom producer, not nil
assert_equal custom_producer, producer_read_during_setup

# The custom producer should still be the active producer after setup completes
# (configure_components uses ||= so it should NOT overwrite a non-nil producer)
assert_equal custom_producer, Karafka::App.config.producer
