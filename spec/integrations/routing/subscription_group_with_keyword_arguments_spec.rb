# frozen_string_literal: true

# Karafka should reject keyword arguments on the top-level subscription group, with and without
# a name, with an ArgumentError and still allow named and nameless subscription groups.

setup_karafka

errors = []

begin
  draw_routes(create_topics: false) do
    subscription_group :group1, kafka: { "bootstrap.servers": "127.0.0.1:9092" } do
      topic :topic1 do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue ArgumentError => e
  errors << e.message
end

begin
  draw_routes(create_topics: false) do
    subscription_group kafka: { "bootstrap.servers": "127.0.0.1:9092" } do
      topic :topic1 do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue ArgumentError => e
  errors << e.message
end

assert_equal ["no keywords accepted"] * 2, errors
assert Karafka::App.routes.empty?

draw_routes(create_topics: false) do
  subscription_group :group2 do
    topic :topic2 do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  subscription_group do
    topic :topic3 do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

names = Karafka::App.routes.flat_map(&:topics).flat_map(&:to_a).map(&:subscription_group_details)

assert_equal "group2", names.first[:name]
assert names.last[:name].is_a?(String)
