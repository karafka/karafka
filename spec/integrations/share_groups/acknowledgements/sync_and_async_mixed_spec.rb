# frozen_string_literal: true

# Share group (KIP-932) batch mixing async and sync (`!`) acknowledgements of all the states: each
# sync one is confirmed (true), accepted and rejected records are never delivered again and released
# ones come back once (delivery count 2) to be accepted.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      result = if message.delivery_count > 1
        DT[:redelivered] << message.raw_payload
        message.offset.even? ? mark_as_accepted!(message) : mark_as_accepted(message)
      else
        case message.raw_payload.split("-").first
        when "accept" then mark_as_accepted(message)
        when "accept!" then mark_as_accepted!(message)
        when "release" then mark_as_released(message)
        when "release!" then mark_as_released!(message)
        when "reject" then mark_as_rejected(message)
        else mark_as_rejected!(message)
        end
      end

      DT[:results] << result
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

states = %w[accept accept! release release! reject reject!]
payloads = Array.new(3) { |i| states.map { |state| "#{state}-#{i}" } }.flatten
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
assert(DT[:results].all?)
