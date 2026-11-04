# frozen_string_literal: true

# Share group (KIP-932): a quiet Karafka process leaves the share group, so it does not acquire
# records in the background. Records produced while it is quiet go right away to another member of
# the group as their first delivery.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }

    DT[:consumed] << true
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

SUBSCRIPTION_GROUP = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

Karafka.monitor.subscribe("app.quiet") { DT[:quiet] << true }

produce(DT.topic, "first")

Thread.new do
  sleep(0.1) while DT[:consumed].empty?

  Process.kill("TSTP", Process.pid)

  sleep(0.1) while DT[:quiet].empty?

  member = Rdkafka::Config.new(SUBSCRIPTION_GROUP.kafka).share_consumer
  member.subscribe(DT.topic)

  produce_many(DT.topic, DT.uuids(20))

  started_at = Time.now

  while DT[:member].size < 20 && Time.now - started_at < 60
    member.poll(500).each do |message|
      DT[:member] << message.delivery_count
      member.acknowledge(message, :accept)
    end
  end

  DT[:took] = Time.now - started_at

  member.commit_sync
  member.close

  Process.kill("QUIT", Process.pid)
end

start_karafka_and_wait_until { false }

assert_equal 20, DT[:member].size
assert_equal [1], DT[:member].uniq
# Not held by the quiet process until its acquisition lock expires (30 seconds by default)
assert DT[:took] < 20
