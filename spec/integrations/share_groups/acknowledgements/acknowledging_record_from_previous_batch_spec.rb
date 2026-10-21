# frozen_string_literal: true

# Share group (KIP-932) acknowledging a message object kept from a previous batch. Records are
# identified by topic/partition/offset, so when the record was redelivered in the current batch the
# stale object acknowledges the current delivery (and the fresh one is then a no-op). When the
# record is not part of the current batch, there is nothing to acknowledge and false is returned,
# like when marking a no longer owned partition for consumer groups.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      case [message.raw_payload, message.delivery_count]
      when ["a", 1]
        # Left unacknowledged, so released and redelivered
        DT[:stored] = message
      when ["a", 2]
        DT[:results] << mark_as_accepted(DT[:stored])
        DT[:results] << mark_as_accepted(message)
      when ["b", 1]
        # Record "a" was already accepted and is not part of this batch
        DT[:stale] << mark_as_rejected(DT[:stored])
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "a")

start_karafka_and_wait_until do
  if DT[:results].size >= 2 && !DT.key?(:produced)
    DT[:produced] = true
    produce(DT.topic, "b")
  end

  if DT[:accepted].include?("b")
    DT[:accepted_at] = Time.now unless DT.key?(:accepted_at)

    # Give the broker time to redeliver anything that was not settled
    Time.now - DT[:accepted_at] > 5
  else
    false
  end
end

# The stale object acknowledged the redelivered record, the fresh one was then a no-op
assert_equal [true, false], DT[:results]
assert_equal [false], DT[:stale]
assert_equal [["a", 1], ["a", 2], ["b", 1]], DT[:deliveries]
assert_equal ["b"], DT[:accepted]
