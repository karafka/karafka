# frozen_string_literal: true

# Karafka should not allow for same topic to be present in multiple subscription groups in the same
# consumer group with same subscription group name

setup_karafka do |config|
  config.strict_topics_namespacing = false
end

failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group :a do
      topic 'namespace_collision' do
        consumer Class.new
      end
    end

    subscription_group :a do
      topic 'namespace_collision' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
