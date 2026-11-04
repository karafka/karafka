# frozen_string_literal: true

# Share group (KIP-932) client should publish client.events_poll when it services the rdkafka
# main queue, with the share client as the caller and its subscription group.

setup_karafka do |config|
  config.internal.tick_interval = 1_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    # Long enough for the listener to service events while waiting on this job
    sleep(3)

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

Karafka::App.monitor.subscribe("client.events_poll") do |event|
  DT[:events] << event
end

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT[:accepted].size >= 1 && DT[:events].size >= 3
end

assert DT[:events].size >= 3

DT[:events].each do |event|
  assert event[:caller].is_a?(Karafka::Connection::ShareGroups::Client)
  assert_equal share_sg, event[:subscription_group]
  assert_equal share_sg, event[:caller].subscription_group
end
