# frozen_string_literal: true

# Share group (KIP-932) should handle records of different sizes properly, including ones bigger
# than the `fetch.message.max.bytes` setting (it is a soft limit and the fetch still progresses).

setup_karafka do |config|
  config.kafka[:"message.max.bytes"] = 50_000
  config.kafka[:"fetch.message.max.bytes"] = 20_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:sizes] << message.raw_payload.bytesize
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

SIZES = [1_000, 10_000, 30_000, 5].freeze

SIZES.each { |size| produce(DT.topic, "x" * size) }

start_karafka_and_wait_until do
  DT[:sizes].size >= SIZES.size
end

assert_equal SIZES.sort, DT[:sizes].sort
