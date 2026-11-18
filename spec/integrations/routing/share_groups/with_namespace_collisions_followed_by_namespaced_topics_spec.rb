# frozen_string_literal: true

# Karafka should reject topics with metrics namespace collisions within the same share group also
# when other namespaced topics without collisions are drawn after them

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    share_group "share-group" do
      topic "namespace_collision" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
      end

      topic "namespace.collision" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
      end

      topic "other_namespaced" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
