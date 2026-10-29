# frozen_string_literal: true

# Share group (KIP-932) records acknowledged after their acquisition lock expired: the broker has
# already handed them back and rejects the acknowledgement with `invalid_record_state`, which is
# reported as an error. The records are delivered again and the group keeps consuming.

setup_karafka(allow_errors: %w[connection.client.acknowledgement.error])

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "connection.client.acknowledgement.error"

  DT[:rejections] << [event[:error].code, event[:offsets].flat_map { |details| details[:offsets] }]
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]
    end

    # Process the first delivery longer than the 15 seconds lock
    sleep(20) if messages.first.delivery_count == 1

    messages.each do |message|
      DT[:accepted] << message.raw_payload if message.delivery_count > 1
      mark_as_accepted(message)
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

setup_share_group(configs: { "share.record.lock.duration.ms" => "15000" })

produce_many(DT.topic, %w[a b])

start_karafka_and_wait_until do
  DT[:accepted].uniq.sort == %w[a b] && !DT[:rejections].empty?
end

assert_equal :invalid_record_state, DT[:rejections].first.first
assert_equal [0, 1], DT[:rejections].flat_map(&:last).uniq.sort
assert_equal [1, 2], DT[:deliveries].map(&:last).uniq.sort
