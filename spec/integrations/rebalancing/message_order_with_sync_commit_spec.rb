# frozen_string_literal: true

# Messages should not be reprocessed out of order during a rebalance
# triggered by an unhealthy consumer with additional manual synchronous
# commits using #mark_as_consumed!.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.kafka[:"auto.commit.interval.ms"] = 5_000

  config.max_wait_time = 10_000
  config.max_messages = 20
  config.initial_offset = "latest"
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Wait until some amount of messages has been already processed to spice things up
      if condition_met?(message) &&
          !DT.key?(:contested_message) &&
          DT[:consecutive_messages].size >= 60
        DT[:contested_message] << message

        sleep(0.1) until DT.key?(:second_closed)
      end

      DT[:consecutive_messages] << [message.payload["key"], message.partition, message.offset]

      next if mark_as_consumed!(message)

      DT[:failed_commits] << message.payload["key"]

      return
    end
  end

  private

  def condition_met?(message)
    # Wait until we receive a batch with more than 3 messages, where the current one follows
    # at least 2 other messages in order to avoid false positives and give the second consumer
    # a chance to reprocess the whole batch.
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
          payload: { "key" => SecureRandom.uuid }.to_json
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
    key = JSON.parse(message.payload)["key"]

    DT[:second_consumer] << [key, message.partition, message.offset]
    DT[:consecutive_messages] << [key, message.partition, message.offset]
    consumer.store_offset(message)

    next unless DT[:contested_message].first&.payload&.dig("key") == key

    # Stop at the contested message
    break
  end

  consumer.commit(nil, false)
  consumer.close

  DT[:second_closed] = true
end

wait_until do
  # Wait until the second consumer gets to the contested message and processes it
  other_consumer.join && DT[:second_closed] == true && DT.key?(:failed_commits)
end

# Make sure that strict order is preserved (excluding the duplicated message)
offsets_by_partition = DT[:consecutive_messages].group_by { |_, partition, _| partition }
offsets_by_partition.each_value do |triples|
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

assert_equal contested_message_key, DT[:contested_message].first.payload["key"]

assert(second_consumer_offsets.none? { |offset| offset < DT[:contested_message].first.offset })

# Contested message should have been reprocessed twice
count = DT[:consecutive_messages].count do |key, _, _|
  key == DT[:contested_message].first.payload["key"]
end

assert_equal(2, count)

# The only failed commit should be that of the contested message
assert_equal 1, DT[:failed_commits].size
assert_equal DT[:contested_message].first.payload["key"], DT[:failed_commits].first
