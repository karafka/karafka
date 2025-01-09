# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to define extra method that we can use to alter headers

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each_with_index do |message, index|
      if (index % 2).zero?
        pipe_async(topic: DT.topics[1], message: message)
      else
        pipe_sync(topic: DT.topics[1], message: message)
      end
    end
  end

  private

  def enhance_pipe_message(pipe_message_hash, message)
    pipe_message_hash[:headers]['extra_data'] = '1'
    pipe_message_hash[:headers]['extra_test'] = message.raw_payload
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
  produce_many(DT.topic, SETS[i], key: %w[BBBBBBBBB AAAAAAAAA][i].to_s)
end

start_karafka_and_wait_until do
  DT[:piped].count >= 100
end

DT[:piped].each do |message|
  headers = message.headers

  original_partition = headers['original_partition'].to_i

  assert SETS[original_partition].include?(message.raw_payload)
  assert [0, 1].include?(original_partition)
  assert %w[BBBBBBBBB AAAAAAAAA].include?(message.key)
  assert_equal headers['original_topic'], DT.topics.first
  assert_equal headers['original_topic'], DT.topics.first
  assert_equal headers['extra_data'], '1'
  assert_equal message.raw_payload, headers['extra_test']
end
