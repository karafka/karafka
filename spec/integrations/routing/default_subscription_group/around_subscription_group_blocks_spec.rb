# frozen_string_literal: true

# Karafka should keep all topics drawn without an explicit subscription group in one default
# subscription group of their consumer group, also when subscription group blocks are drawn in
# between them, so they are consumed with one connection

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:subscription_groups][topic.name] = topic.subscription_group.id
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  subscription_group :explicit do
    topic DT.topics[1] do
      consumer Consumer
    end
  end

  topic DT.topics[2] do
    consumer Consumer
  end

  subscription_group do
    topic DT.topics[3] do
      consumer Consumer
    end
  end

  topic DT.topics[4] do
    consumer Consumer
  end
end

DT[:subscription_groups] = {}

5.times { |i| produce(DT.topics[i], "1") }

start_karafka_and_wait_until do
  DT[:subscription_groups].size >= 5
end

subscription_groups = Karafka::App.subscription_groups.values.first
default = DT[:subscription_groups][DT.topics[0]]

assert_equal 3, subscription_groups.size
assert_equal [DT.topics[0], DT.topics[2], DT.topics[4]], subscription_groups.first.topics.map(&:name)
assert_equal default, DT[:subscription_groups][DT.topics[2]]
assert_equal default, DT[:subscription_groups][DT.topics[4]]
assert_not_equal default, DT[:subscription_groups][DT.topics[1]]
assert_not_equal default, DT[:subscription_groups][DT.topics[3]]
assert_not_equal DT[:subscription_groups][DT.topics[1]], DT[:subscription_groups][DT.topics[3]]
