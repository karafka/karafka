# frozen_string_literal: true

# When using separate subscription groups, each should have it's own underlying client and should
# operate independently for data fetching.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:clients] << client.object_id
  end
end

draw_routes do
  DT.topics.first(10).each do |topic_name|
    subscription_group topic_name do
      topic topic_name do
        consumer Consumer
      end
    end

    create_topic(name: topic_name)
  end
end

messages = DT.topics.first(10).map do |topic_name|
  { topic: topic_name, payload: '1' }
end

Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:clients].uniq.count >= 10
end

assert_equal 10, DT[:clients].uniq.size
