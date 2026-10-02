# frozen_string_literal: true

# Share group (KIP-932) topics should support custom routing features (declared via a
# `ShareGroups::Topic` module), including routing defaults, and expose them in the consumer.

setup_karafka

class CustomAttributes < Karafka::Routing::Features::Base
  module ShareGroups
    module Topic
      def custom_attributes(mine: -100, yours: -200)
        @custom_attributes ||= Config.new(
          mine: mine,
          yours: yours
        )
      end
    end
  end

  Config = Struct.new(
    :mine,
    :yours,
    keyword_init: true
  )
end

CustomAttributes.activate

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }

    DT[:state] = topic.custom_attributes
  end
end

draw_routes(create_topics: false) do
  defaults do
    custom_attributes(mine: 1, yours: 2)
  end

  share_group DT.groups[0] do
    topic DT.topics[0] do
      active true
      consumer Consumer
    end
  end

  share_group DT.groups[1] do
    topic DT.topics[1] do
      active false
      custom_attributes(mine: 3, yours: 4)
    end
  end
end

# Not available on consumer group topics as it targets share groups only
assert !Karafka::Routing::ConsumerGroups::Topic.method_defined?(:custom_attributes)

t1 = Karafka::App.routes[0].topics.first
t2 = Karafka::App.routes[1].topics.first

assert_equal 1, t1.custom_attributes.mine
assert_equal 2, t1.custom_attributes.yours
assert_equal 3, t2.custom_attributes.mine
assert_equal 4, t2.custom_attributes.yours

setup_share_group(DT.topics[0], DT.groups[0])

produce(DT.topics[0], "{}")

start_karafka_and_wait_until do
  DT.key?(:state)
end

assert_equal DT[:state], t1.custom_attributes
