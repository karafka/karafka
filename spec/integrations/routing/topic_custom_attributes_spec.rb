# frozen_string_literal: true

# You should be able to define your own features to assign them to topics
# You should also be able to use it from the consumer

setup_karafka

class CustomAttributes < Karafka::Routing::Features::Base
  module Topic
    def custom_attributes(mine: -100, yours: -200)
      @custom_attributes ||= Config.new(
        mine: mine,
        yours: yours
      )
    end
  end

  Config = Struct.new(
    :mine,
    :yours,
    keyword_init: true
  )
end

CustomAttributes.activate

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:state] = topic.custom_attributes
  end
end

draw_routes(create_topics: true) do
  defaults do
    custom_attributes(mine: 1, yours: 2)
  end

  consumer_group DT.topics[0] do
    topic DT.topics[0] do
      active true
      consumer Consumer
    end
  end

  consumer_group DT.topics[1] do
    topic DT.topics[1] do
      active false
      custom_attributes(mine: 3, yours: 4)
    end
  end
end

t1 = Karafka::App.consumer_groups[0].topics.first
t2 = Karafka::App.consumer_groups[1].topics.first

assert_equal t1.custom_attributes.mine, 1
assert_equal t1.custom_attributes.yours, 2
assert_equal t2.custom_attributes.mine, 3
assert_equal t2.custom_attributes.yours, 4

produce(DT.topics[0], '{}')

start_karafka_and_wait_until do
  DT.key?(:state)
end

assert_equal DT[:state], t1.custom_attributes
