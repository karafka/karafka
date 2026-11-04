# frozen_string_literal: true

# Share group (KIP-932) records keep their headers: all of them are available with string keys.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:records] << [message.raw_payload, message.headers]
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

elements = DT.uuids(10)
elements.each { |data| produce(DT.topic, data, headers: { "value" => data }) }

start_karafka_and_wait_until do
  DT[:records].size >= 10
end

assert_equal elements.sort, DT[:records].map(&:first).sort

DT[:records].each do |payload, headers|
  assert_equal payload, headers.fetch("value")
  assert(headers.keys.all?(String))
end
