# frozen_string_literal: true

# DLQ in the VP mode should collapse and skip when error occurs again in a collapsed mode

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Simulates a broken message that for example cannot be deserialized
      raise StandardError if message.raw_payload == '5'

      # Mark only in a collapsed mode
      mark_as_consumed(message) if collapsed?

      DT[:flow] << [message.offset, object_id, collapsed?]
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:dlq] << message
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(message) { message.raw_payload }
      )
      dead_letter_queue(
        topic: DT.topics[1],
        max_retries: 1
      )
    end

    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

produce_many(DT.topic, (0..9).to_a.map(&:to_s))

start_karafka_and_wait_until do
  !DT[:dlq].empty?
end

p DT[:dlq]

p DT[:flow]
