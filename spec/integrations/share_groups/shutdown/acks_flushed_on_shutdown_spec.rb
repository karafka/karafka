# frozen_string_literal: true

# Share group (KIP-932): acceptances made before a stop are flushed, so after starting the group
# again in the same process accepted records are not delivered again, while the records that were
# left unacknowledged are released and redelivered (with a higher delivery count).

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    if DT[:phase] == [1]
      messages.each_with_index do |message, index|
        DT[:phase1] << message.raw_payload

        if index.even?
          mark_as_accepted(message)
          DT[:accepted] << message.raw_payload
        end
      end

      # Stay in flight until the stop was requested, so this is the only batch of the first run.
      # Bounded so a stuck run can never hang.
      1_000.times do
        break if Karafka::App.stopping?

        sleep(0.01)
      end
    else
      messages.each do |message|
        DT[:phase2] << [message.raw_payload, message.delivery_count]
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

elements = DT.uuids(10)
produce_many(DT.topic, elements)

DT[:phase] << 1

start_karafka_and_wait_until(reset_status: true) do
  DT[:phase1].any?
end

DT[:phase].clear
DT[:phase] << 2

unacked = DT[:phase1] - DT[:accepted]

assert DT[:accepted].any?
assert unacked.any?

start_karafka_and_wait_until do
  DT[:phase2].map(&:first).uniq.size >= elements.size - DT[:accepted].size
end

redelivered = DT[:phase2].map(&:first)

# Accepted records are never delivered again
assert (redelivered & DT[:accepted]).empty?
# Everything not accepted in the first run is consumed in the second one
assert_equal (elements - DT[:accepted]).sort, redelivered.uniq.sort

# Records left unacknowledged in the first run come back with a higher delivery count
DT[:phase2].each do |payload, delivery_count|
  next unless unacked.include?(payload)

  assert delivery_count >= 2
end
