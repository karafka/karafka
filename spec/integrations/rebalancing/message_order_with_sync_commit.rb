# frozen_string_literal: true

# Messages should not be reprocessed out of order during a rebalance with
# additional manual synchronous commits using #mark_as_consumed!.

setup_karafka(allow_errors: %w[consumer.consume.error connection.client.poll.error]) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  # Default librdkafka auto commit interval
  config.kafka[:'auto.commit.interval.ms'] = 5_000

  # Attempt ot batch messages to help trigger the condition for a contested message
  config.max_wait_time = 10_000
  config.max_messages = 20
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Wait until we receive a batch with more than 3 messages, where the current one follows
      # at least 2 other messages in order to avoid false positives and give the second consumer
      # a chance to reprocess the whole batch.
      condition_met = ((messages.metadata.first_offset + 2)..(messages.metadata.last_offset - 1)).cover?(message.offset)

      # Wait until some amount of messages has been already processed to spice things up
      if condition_met && DT.data[:contested_message].empty? && DT.data[:consecutive_messages].count >= 60
        DT[:contested_message] << message
        sleep(0.1) until DT.data.key?(:second_closed)
      end

      DT.data[:consecutive_messages] << [message.payload['key'], message.partition, message.offset]

      # #mark_as_consumed! will raise on the contesed message since by that time
      # the partition will be revoked
      return_value = mark_as_consumed!(message)
      DT[:mark_as_consumed_return_values] << [message.payload, return_value]
      return if return_value == false
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      config(partitions: 3)
      consumer Consumer
    end
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << event[:error]
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
    DT[:consecutive_messages] << [key, message.partition, message.offset]
    consumer.store_offset(message)

    next unless DT[:contested_message].first&.payload&.dig('key') == key

    # Stop at the contested message
    break
  end

  consumer.commit(nil, false)
  consumer.close

  DT[:second_closed] = true
end

wait_until do
  # Wait until the second consumer gets to the contested message and processes it
  other_consumer.join && DT.data[:second_closed] == true && DT[:errors].count == 1
end

# Make sure that strict order is preserved (excluding the duplicated message)
offsets_by_partition = DT[:consecutive_messages].group_by { |_, partition, _| partition }
offsets_by_partition.each do |_, triples|
  previous = nil

  triples.each do |_, _, offset|
    unless previous
      previous = offset
      next
    end

    # Contested message should be duplicated, since it should be processed by both consumers
    contested_message_offset = DT[:contested_message].first.offset
    next if previous == contested_message_offset && offset == contested_message_offset

    assert_equal previous + 1, offset

    previous = offset
  end
end

# Second consumer should have started from the contested message, not from earlier ones
messages_processed_by_second_consumer = DT[:second_consumer].select do |_, partition, _|
  partition == DT[:contested_message].first.partition
end
second_consumer_offsets = messages_processed_by_second_consumer.map { |_, _, offset| offset }
contested_message_key, = messages_processed_by_second_consumer.first

assert_equal contested_message_key, DT[:contested_message].first.payload['key']

assert_equal(true, second_consumer_offsets.none? { |offset| offset < DT[:contested_message].first.offset })

# Contested message should have been reprocessed twice
assert_equal(
  DT[:consecutive_messages].select { |key, _, _| key == DT[:contested_message].first.payload['key'] }.count,
  2
)

# #mark_as_consumed! will raise for the contested message instead of returning `false` ...
absent_return_value = DT[:mark_as_consumed_return_values].find do |key, _|
  key == DT[:contested_message].first.payload['key']
end
assert_equal absent_return_value, nil

# ... it will raise Rdkafka::RdkafkaError instead
assert_equal DT[:errors].count, 1
consumption_error = DT[:errors].first
assert_equal consumption_error.code, :unknown_member_id
assert_equal consumption_error.class, Rdkafka::RdkafkaError
