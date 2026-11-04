# frozen_string_literal: true

# Share group (KIP-932) should consume multiple topics even when there are many subscription
# groups underneath due to non-homogeneous settings. Each subscription group has its own share
# client, yet all of them belong to the same share group.

setup_karafka do |config|
  config.concurrency = 2
end

class Consumer < Karafka::ShareConsumer
  def consume
    sleep(0.1)

    messages.each do |message|
      DT[topic.name] << Thread.current.object_id
      DT[:sizes] << [topic.name, messages.size]
      mark_as_accepted(message)
    end
  end
end

TOPICS = DT.topics.first(5)

draw_routes(create_topics: false) do
  share_group DT.group do
    TOPICS.each_with_index do |topic_name, index|
      topic topic_name do
        # This will force us to have many subscription groups
        max_messages index + 2
        consumer Consumer
      end
    end
  end
end

TOPICS.each { |topic_name| setup_share_group(topic_name) }

TOPICS.each do |topic_name|
  produce_many(topic_name, DT.uuids(10))
end

start_karafka_and_wait_until do
  TOPICS.sum { |topic_name| DT[topic_name].size } >= 50
end

# Ensure we have a subscription group per topic as expected with non-homogeneous settings
assert_equal 5, Karafka::App.routes.first.subscription_groups.size
TOPICS.each { |topic_name| assert_equal 10, DT[topic_name].size }
# All workers should be in use
assert_equal 2, TOPICS.flat_map { |topic_name| DT[topic_name] }.uniq.size
# Each topic respects its own max messages
TOPICS.each_with_index do |topic_name, index|
  sizes = DT[:sizes].select { |name, _| name == topic_name }.map(&:last)
  assert sizes.max <= index + 2, [topic_name, sizes]
end
