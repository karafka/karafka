# frozen_string_literal: true

# Karafka should reject topics with metrics namespace collisions within the same consumer group
# also when other namespaced topics without collisions are drawn after them

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    topic "namespace_collision" do
      consumer Class.new(Karafka::BaseConsumer)
    end

    topic "namespace.collision" do
      consumer Class.new(Karafka::BaseConsumer)
    end

    topic "other_namespaced" do
      consumer Class.new(Karafka::BaseConsumer)
    end

    topic "another.namespaced" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
