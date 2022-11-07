# frozen_string_literal: true

# Same as pure DLQ version until rebalance
# Needs to go to same partition

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

create_topic(name: DT.topics[1], partitions: 10)

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.partition
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    manual_offset_management true
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:broken].count >= 10
end

assert_equal 1, DT[:broken].uniq.count
