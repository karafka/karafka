# frozen_string_literal: true

# Karafka should allow for same topic to be present in multiple subscription groups in the same
# consumer group as long as subscription groups have different names and same consumer class

setup_karafka do |config|
  config.strict_topics_namespacing = false
end

failed = false
consumer_class = Class.new

begin
  draw_routes(create_topics: false) do
    subscription_group :a do
      topic 'namespace_collision' do
        consumer consumer_class
      end
    end

    subscription_group :b do
      topic 'namespace_collision' do
        consumer consumer_class
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
