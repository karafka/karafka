# frozen_string_literal: true

# Karafka should now allow for topics that would have metrics namespace collisions
# It should not be allowed within same consumer group

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    topic 'namespace_collision' do
      consumer Class.new
    end

    topic 'namespace.collision' do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

# Should be ok from multiple consumer groups

Karafka::App.routes.clear

failed = false

begin
  draw_routes(create_topics: false) do
    consumer_group :a do
      topic 'namespace_collision' do
        consumer Class.new
      end
    end

    consumer_group :b do
      topic 'namespace.collision' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
