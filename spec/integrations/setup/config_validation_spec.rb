# frozen_string_literal: true

# Karafka should use rdkafka errors raised when invalid sub-settings after routing is defined
# We do it after the routing, so any overwrites are also handled

guarded = []
errors = []

begin
  setup_karafka do |config|
    config.kafka = { 'message.max.bytes': 0, 'message.copy.max.bytes': -1 }
  end

  draw_routes do
    consumer_group 'usual' do
      topic 'regular' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  errors << e
  guarded << true
end

begin
  setup_karafka do |config|
    config.kafka = { 'message.max.bytes' => 0, 'message.copy.max.bytes' => -1 }
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  errors << e
  guarded << true
end

assert errors.first.message.include?('routes.usual.regular.kafka')
assert errors.last.message.include?('config.kafka.message.max.bytes')
assert_equal [true, true], guarded
