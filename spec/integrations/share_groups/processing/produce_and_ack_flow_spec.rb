# frozen_string_literal: true

# Share group (KIP-932) consumers producing a derived record for each consumed record before
# accepting it produce exactly one derived record per accepted record on the happy path.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      produce_sync(topic: DT.topics[1], payload: "derived-#{message.raw_payload}")
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

elements = DT.uuids(20)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:accepted].size >= 20
end

# Give the broker a chance to redeliver anything that was not settled
sleep(3)

derived = Karafka::Admin.read_topic(DT.topics[1], 0, 100).map(&:raw_payload)

assert_equal elements.sort, DT[:accepted].sort
assert_equal elements.map { |element| "derived-#{element}" }.sort, derived.sort
