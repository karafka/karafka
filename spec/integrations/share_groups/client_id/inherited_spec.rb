# frozen_string_literal: true

# Share group (KIP-932) clients should get the root `client_id` injected as `kafka.client.id` when
# it is not set on the librdkafka level, so the running share consumer reports it.

setup_karafka do |config|
  config.client_id = "test-app"
end

assert_equal nil, Karafka::App.config.kafka[:"client.id"]

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
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

assert_equal "test-app", share_sg.kafka[:"client.id"]

Karafka.monitor.subscribe("statistics.emitted") do |event|
  next unless event[:subscription_group_id] == share_sg.id

  DT[:client_ids] << event[:statistics]["client_id"]
end

start_karafka_and_wait_until do
  !DT[:client_ids].empty?
end

assert_equal ["test-app"], DT[:client_ids].uniq
