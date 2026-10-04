# frozen_string_literal: true

# Share group (KIP-932) should recover from a critical listener error by resetting its share
# client and keep publishing statistics from the new librdkafka client.

setup_karafka(allow_errors: %w[connection.listener.fetch_loop.error])

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

setup_share_group

SuperException = Class.new(Exception)

share_sg = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  next unless event[:subscription_group_id] == share_sg.id

  DT[:names] << event[:statistics].fetch("name")
end

Karafka::App.monitor.subscribe("client.reset") do |event|
  DT[:resets] << event[:subscription_group]
end

# Force a client reset once the current client has published statistics (hacky, but works)
Karafka::App.monitor.subscribe("connection.listener.fetch_loop") do |event|
  raise SuperException if DT[:names].include?(event[:client].name)
end

start_karafka_and_wait_until do
  DT[:names].uniq.size >= 3
end

names = DT[:names].uniq
client_id = Karafka::App.config.client_id

# Each reset built a new client that published statistics, in order
assert names.size >= 3
assert DT[:resets].size >= 2
assert(DT[:resets].all? { |sg| sg == share_sg })

previous_index = 0
names.each do |name|
  current_index = name.split("-").last.to_i
  assert previous_index < current_index
  assert name.start_with?(client_id)
  previous_index = current_index
end
