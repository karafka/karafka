# frozen_string_literal: true

# Share group (KIP-932) records with an empty payload, no key and many headers are consumed and
# accepted like any other.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:messages] << [message.raw_payload, message.key, message.headers, message.delivery_count]
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

setup_share_group

headers = Array.new(50) { |index| ["header-#{index}", "value-#{index}"] }.to_h

10.times do |index|
  produce(DT.topic, "", headers: headers.merge("index" => index.to_s))
end

start_karafka_and_wait_until do
  DT[:messages].size >= 10
end

# Give the broker a chance to redeliver anything that was not settled
sleep(3)

assert_equal 10, DT[:messages].size

DT[:messages].each_with_index do |(payload, key, message_headers, delivery_count), index|
  assert_equal "", payload
  assert_equal nil, key
  assert_equal headers.merge("index" => index.to_s), message_headers
  assert_equal 1, delivery_count
end
