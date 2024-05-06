# frozen_string_literal: true

# You should be able to define your own features to assign them to topics

setup_karafka

class CustomAttributes < Karafka::Routing::Features::Base
  module Topic
    def custom_attributes(mine: -100, yours: -200)
      @custom_attributes ||= Config.new(
        active: true,
        mine: mine,
        yours: yours
      )
    end
  end

  Config = Struct.new(
    :active,
    :mine,
    :yours,
    keyword_init: true
  ) { alias_method :active?, :active }
end

CustomAttributes.activate

draw_routes(create_topics: false) do
  defaults do
    active false
    custom_attributes(mine: 1, yours: 2)
  end

  consumer_group :test do
    topic 'topic2'
  end

  consumer_group :test2 do
    topic 'topic1' do
      custom_attributes(mine: 3, yours: 4)
    end
  end
end

t1 = Karafka::App.consumer_groups[0].topics.first
t2 = Karafka::App.consumer_groups[1].topics.first

assert_equal 'topic2', t1.name
assert_equal 'topic1', t2.name
assert_equal t1.custom_attributes.mine, 1
assert_equal t1.custom_attributes.yours, 2
assert_equal t2.custom_attributes.mine, 3
assert_equal t2.custom_attributes.yours, 4
