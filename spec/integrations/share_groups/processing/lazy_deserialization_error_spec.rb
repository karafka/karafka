# frozen_string_literal: true

# Share group (KIP-932) lazy deserialization errors surface when `#payload` is accessed in
# `#consume`. Without a rescue the consumption fails and the unacknowledged records are released
# and redelivered. With a rescue rejecting the broken record, it never comes back.

setup_karafka(allow_errors: %w[consumer.consume.error])

# Fails for the "broken" record on its first delivery only, so the redelivery recovers
class TransientDeserializer
  def call(message)
    raise StandardError if message.raw_payload == "broken" && message.delivery_count == 1

    message.raw_payload
  end
end

# Always fails for the "broken" record
class PermanentDeserializer
  def call(message)
    raise ArgumentError if message.raw_payload == "broken"

    message.raw_payload
  end
end

class NoRescueConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:no_rescue_deliveries] << [message.raw_payload, message.delivery_count]
      DT[:no_rescue] << message.payload
      mark_as_accepted(message)
    end
  end
end

class RescueConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:rescue_deliveries] << [message.raw_payload, message.delivery_count]

      begin
        DT[:rescue] << message.payload
        mark_as_accepted(message)
      rescue ArgumentError
        DT[:rejected] << message.raw_payload
        mark_as_rejected(message)
      end
    end
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:caller].topic.name if event[:type] == "consumer.consume.error"
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer NoRescueConsumer
      deserializer TransientDeserializer.new
    end

    topic DT.topics[1] do
      consumer RescueConsumer
      deserializer PermanentDeserializer.new
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

payloads = %w[a b c broken d e f]

produce_many(DT.topics[0], payloads)
produce_many(DT.topics[1], payloads)

start_karafka_and_wait_until do
  DT[:no_rescue].uniq.size >= payloads.size &&
    (DT[:rescue].size + DT[:rejected].size) >= payloads.size
end

# Give the broker a chance to redeliver anything that was not settled
sleep(5)

# Without a rescue: the error failed the consumption and the broken record came back
assert_equal [DT.topics[0]], DT[:errors].uniq
assert_equal payloads.sort, DT[:no_rescue].uniq.sort

broken_counts = DT[:no_rescue_deliveries].filter_map do |payload, count|
  count if payload == "broken"
end

assert broken_counts.include?(1)
assert broken_counts.max >= 2

# With a rescue: the broken record was rejected once and never redelivered
assert_equal %w[broken], DT[:rejected]
assert_equal (payloads - %w[broken]).sort, DT[:rescue].sort
assert_equal [1], DT[:rescue_deliveries].map(&:last).uniq
assert_equal payloads.size, DT[:rescue_deliveries].size
