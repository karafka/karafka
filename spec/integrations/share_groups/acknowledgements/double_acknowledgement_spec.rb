# frozen_string_literal: true

# Share group (KIP-932) acknowledging the same record twice within a batch: the second
# acknowledgement (async or sync, same or different state) is ignored and returns false, the first
# one wins, nothing is redelivered and the group keeps consuming records produced later.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      first = mark_as_accepted(message)

      second = case message.offset % 3
      when 0 then mark_as_rejected(message)
      when 1 then mark_as_accepted!(message)
      else mark_as_released!(message)
      end

      DT[:results] << [first, second]
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

first_wave = DT.uuids(10)
second_wave = DT.uuids(10)
produce_many(DT.topic, first_wave)

start_karafka_and_wait_until do
  if DT[:deliveries].size >= 10 && !DT.key?(:produced)
    DT[:produced] = true
    produce_many(DT.topic, second_wave)
  end

  if DT[:deliveries].size >= 20
    DT[:done_at] = Time.now unless DT.key?(:done_at)

    # Give the broker time to redeliver anything that was not accepted
    Time.now - DT[:done_at] > 5
  else
    false
  end
end

assert_equal (first_wave + second_wave).sort, DT[:deliveries].map(&:first).sort
assert(DT[:deliveries].all? { |_, count| count == 1 })
assert_equal [[true, false]], DT[:results].uniq
