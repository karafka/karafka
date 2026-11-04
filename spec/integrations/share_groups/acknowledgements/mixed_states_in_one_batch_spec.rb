# frozen_string_literal: true

# Share group (KIP-932) batch mixing all the acknowledgement states: accepted and rejected records
# are never delivered again, while released ones come back (delivery count 2) and are accepted.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      if message.delivery_count > 1
        DT[:redelivered] << message.raw_payload
        mark_as_accepted(message)
      elsif message.raw_payload.start_with?("accept")
        mark_as_accepted(message)
      elsif message.raw_payload.start_with?("release")
        mark_as_released(message)
      else
        mark_as_rejected(message)
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

payloads = Array.new(3) { |i| %W[accept-#{i} release-#{i} reject-#{i}] }.flatten
released = payloads.select { |payload| payload.start_with?("release") }
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  if DT[:redelivered].uniq.size >= released.size
    DT[:settled_at] = Time.now unless DT.key?(:settled_at)

    # Give the broker time to redeliver anything that was not settled
    Time.now - DT[:settled_at] > 5
  else
    false
  end
end

payloads.each do |payload|
  counts = DT[:deliveries].select { |name, _| name == payload }.map(&:last)

  assert_equal(payload.start_with?("release") ? [1, 2] : [1], counts, payload)
end

assert_equal released.sort, DT[:redelivered].sort
