# frozen_string_literal: true

# Karafka should allow for topics that would have metrics namespace collisions if strict topic
# names validation is off

setup_karafka do |config|
  config.strict_topics_namespacing = false
end

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

assert !failed
