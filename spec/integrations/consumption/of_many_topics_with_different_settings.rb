# frozen_string_literal: true

# Karafka should be able to consume multiple topics even when there are many subscription groups
# underneath due to non-homogeneous settings
# Usually configuration like this may not be optimal with too many subscription groups, nonetheless
# we should support it

setup_karafka do |config|
  config.concurrency = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.1)

    messages.each do
      DT[topic.name] << Thread.current.object_id
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    DT.topics.first(10).each_with_index do |topic_name, index|
      topic topic_name do
        # This will force us to have many subscription groups
        max_messages index + 2
        consumer Consumer
      end

      10.times { produce(topic_name, SecureRandom.uuid) }
    end
  end
end

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 100
end

# Ensure we have 10 subscription groups as expected when non-homogeneous settings are used
assert_equal 10, Karafka::App.subscription_groups.size
# All workers should be in use
assert_equal 10, DT.data.keys.size
# All workers consumers should consume same number of messages
assert_equal 2, DT.data.values.flatten.uniq.size
