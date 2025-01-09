# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to pipe data to a different topic and it should be received
# Operating in transactional mode

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 10
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    transaction do
      messages.each_with_index do |message, index|
        if (index % 2).zero?
          pipe_async(topic: DT.topics[1], message: message)
        else
          pipe_sync(topic: DT.topics[1], message: message)
        end
      end
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:piped] << message
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topics[0] do
      config(partitions: 2)
      consumer Consumer1
    end
  end

  topic DT.topics[1] do
    consumer Consumer2
  end
end

P1 = DT.uuids(50)
P2 = DT.uuids(50)

SETS = [P1, P2].freeze

2.times do |i|
  produce_many(DT.topic, SETS[i], partition: i)
end

start_karafka_and_wait_until do
  DT[:piped].count >= 100
end

DT[:piped].each do |message|
  headers = message.headers

  original_partition = headers['original_partition'].to_i

  assert SETS[original_partition].include?(message.raw_payload)
  assert [0, 1].include?(original_partition)
  assert %w[0 1].include?(message.key)
  assert_equal headers['original_topic'], DT.topics.first
  assert_equal headers['original_consumer_group'], DT.consumer_group
end
