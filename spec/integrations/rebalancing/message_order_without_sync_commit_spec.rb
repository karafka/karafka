# frozen_string_literal: true

# Messages can be reprocessed out of order during a rebalance triggered
# by an unhealthy consumer without additional manual synchronous commits.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.kafka[:'auto.commit.interval.ms'] = 5_000

  config.max_wait_time = 10_000
  config.max_messages = 20
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Wait until some amount of messages has been already processed to spice things up
      if condition_met?(message) &&
         DT.data[:contested_message].empty? &&
         DT.data[:consecutive_messages].size >= 60
        DT[:contested_message_tuple] << [message, messages.metadata.first_offset]
        sleep(0.1) until DT.data.key?(:second_closed)
      end

      DT.data[:consecutive_messages] << [:first, message.partition, message.offset]
    end
  end

  def revoked
    DT[:revoked] << true
  end

  private

  # Wait until we receive a batch with more than 3 messages, where the current one follows
  # at least 2 other messages in order to avoid false positives and give the second consumer
  # a chance to reprocess the whole batch.
  def condition_met?(message)
    (
      (messages.metadata.first_offset + 2)..(messages.metadata.last_offset - 1)
    ).cover?(message.offset)
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 3)
    consumer Consumer
  end
end

Thread.new { Karafka::Server.run }

sleep(10)

Thread.new do
  partitions = [0, 1, 2].cycle

  loop do
    begin
      messages = Array.new(20) do
        {
          topic: DT.topic,
          partition: partitions.next,
          payload: { 'key' => SecureRandom.uuid }.to_json
        }
      end

      Karafka::App.producer.produce_many_sync(messages)
    rescue WaterDrop::Errors::ProducerClosedError
      break
    end

    sleep(1)
  end
end

other_consumer = Thread.new do
  sleep(10)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    key = JSON.parse(message.payload)['key']

    DT[:second_consumer] << [key, message.partition, message.offset]
    DT[:consecutive_messages] << [:second, message.partition, message.offset]
    consumer.store_offset(message)

    next unless DT[:contested_message_tuple].first.first&.payload&.dig('key') == key

    # Stop at the contested message
    break
  end

  consumer.commit(nil, false)
  consumer.close

  DT[:second_closed] = true
end

wait_until do
  # Wait until the second consumer gets to the contested message and processes it
  other_consumer.join && DT.data[:second_closed] == true && DT.data[:revoked].size >= 1
end

contested_message, contested_batch_first_offset = DT[:contested_message_tuple].first

message_from_contested_partition = DT[:consecutive_messages].select do |_, partition, _|
  partition == contested_message.partition
end

contested_offset_range = (contested_batch_first_offset..contested_message.offset)
messages_from_contested_batch = message_from_contested_partition.select do |_, _, offset|
  contested_offset_range.cover?(offset)
end

# Each message from the contested batch should have been processed once by both consumers,
# twice in total
duplicate_counts = messages_from_contested_batch
                   .group_by { |_, _, offset| offset }
                   .values
                   .map { |group| group.uniq.size }

assert(duplicate_counts.all?(2))

# Second consumer should have started from the first offset in a contested batch
messages_processed_by_second_consumer = DT[:second_consumer].select do |_, partition, _|
  partition == contested_message.partition
end
_, _, first_message_from_contested_batch_offset = messages_processed_by_second_consumer.first
assert_equal first_message_from_contested_batch_offset, contested_batch_first_offset
