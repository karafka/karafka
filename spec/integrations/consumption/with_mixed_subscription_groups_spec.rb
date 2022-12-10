# frozen_string_literal: true

# When using separate subscription groups for every nth topic, we should have proper number of
# underlying clients.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:clients] << client.object_id
  end
end

draw_routes do
  DT.topics.first(10).each_slice(2) do |topics|
    slice_uuid = SecureRandom.hex(6)

    subscription_group slice_uuid do
      topics.each do |topic_name|
        topic topic_name do
          consumer Consumer
        end
      end
    end
  end
end

messages = DT.topics.first(10).map do |topic_name|
  { topic: topic_name, payload: '1' }
end

Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:clients].uniq.count >= 5 && sleep(5)
end

assert_equal 5, DT[:clients].uniq.size
