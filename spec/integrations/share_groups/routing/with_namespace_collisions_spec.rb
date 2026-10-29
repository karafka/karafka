# frozen_string_literal: true

# Share group (KIP-932) topics that would have metrics namespace collisions (dot vs underscore)
# should not be allowed within the same share group, nor should inconsistently namespaced topic
# names, unless strict topics namespacing is disabled.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

failed = []

begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "namespace_collision" do
        consumer Consumer
      end

      topic "namespace.collision" do
        consumer Consumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("routes.sg.topics"), e.message

  failed << :collision
end

clear_app_draws

begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "namespace.inconsistent_name" do
        consumer Consumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("routes.sg.namespace.inconsistent_name.name"), e.message

  failed << :inconsistent
end

clear_app_draws

assert_equal %i[collision inconsistent], failed

Karafka::App.config.strict_topics_namespacing = false

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "namespace_collision" do
      consumer Consumer
    end

    topic "namespace.collision" do
      consumer Consumer
    end

    topic "namespace.inconsistent_name" do
      consumer Consumer
    end
  end
end

assert_equal 3, Karafka::App.routes.share_groups.first.topics.size
