# frozen_string_literal: true

# Share group (KIP-932) statistics: a running share group emits `statistics.emitted` events
# attributed to its subscription group (requires karafka-rdkafka >= 0.30.1, where the share
# consumer reports its librdkafka name so the statistics callback can route correctly).

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
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

share_sg = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

Karafka.monitor.subscribe("statistics.emitted") do |event|
  DT[:stats] << event[:subscription_group_id] if event[:subscription_group_id] == share_sg.id
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:accepted].size >= 5 && !DT[:stats].empty?
end

# We consumed and at least one statistics.emitted fired for our share subscription group
assert DT[:accepted].size >= 5
assert !DT[:stats].empty?
