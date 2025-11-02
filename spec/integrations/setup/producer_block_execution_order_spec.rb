# frozen_string_literal: true

# Karafka should execute the producer configuration block AFTER all user settings are applied
# and AFTER the default producer is created. This ensures the block has access to the fully
# configured producer and can override any defaults.
# Karafka should also setup producer after ALL Karafka level configuration is available

setup_karafka do |config|
  # Producer block runs after setup
  config.producer do |producer_config|
    # Should be able to customize producer kafka settings
    producer_config.kafka[:'max.in.flight.requests.per.connection'] = 1
  end

  config.kafka[:'bootstrap.servers'] = 'test'
end

producer = Karafka::App.config.producer

# Producer should have the setting from the block
assert_equal 1, producer.config.kafka[:'max.in.flight.requests.per.connection']
assert_equal 'test', producer.config.kafka[:'bootstrap.servers']

# Producer config should NOT leak back to Karafka
assert_equal nil, Karafka::App.config.kafka[:'max.in.flight.requests.per.connection']


# Producer should be properly created
assert producer.is_a?(WaterDrop::Producer)
