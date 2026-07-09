# frozen_string_literal: true

# The static group membership counterpart of the
# rebalancing/stuck_rebalance_forceful_shutdown_spec.rb scenario.
#
# The forceful shutdowns there require a rebalance to be in-flight while the consumer is being
# stopped - the deployment itself is what generates those rebalances: every dynamic member that
# leaves triggers one and every replacement pod that joins triggers another, so with many pods
# rolling, shutdowns constantly land in the middle of unsettled (and with a slow member, stuck)
# rebalances.
#
# With static group membership (`group.instance.id`) there is nothing to get stuck on:
# - a stopping static member does not send a leave group request, so its shutdown triggers no
#   rebalance (and Karafka skips the pre-close unsubscribe on purpose, as re-subscribing would
#   reshuffle the assignments),
# - its replacement re-joining within `session.timeout.ms` gets the exact same assignment back
#   without rebalancing the rest of the group.
#
# This spec verifies both: a rolling restart of a static Karafka member is fast + graceful and
# the other group member observes no assignment change at any point.

setup_karafka do |config|
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
  # Same as in the trigger scenario counterpart - yet with static membership the shutdown does
  # not even come close to reaching it
  config.shutdown_timeout = 5_000
  config.kafka[:"group.instance.id"] = SecureRandom.hex(6)
  # The restart must happen within this window for the assignment to be preserved
  config.kafka[:"session.timeout.ms"] = 30_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << [message.partition, message.raw_payload]
    end
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

# Tracks how long each of the two shutdowns took
Karafka.monitor.subscribe("app.stopping") { DT[:stopping_at] << Time.now.to_f }
Karafka.monitor.subscribe("app.stopped") { DT[:stopped_at] << Time.now.to_f }

# Karafka producer gets closed on the first server stop, hence a standalone one
PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.logger = Karafka::App.config.logger
  producer_config.max_wait_timeout = 120_000
end

# The other static group member. It records every distinct assignment it observes - across the
# Karafka member rolling restart this history must not grow
other = Thread.new do
  consumer = setup_rdkafka_consumer(
    "partition.assignment.strategy": "cooperative-sticky",
    "group.instance.id": "other-static-member",
    "session.timeout.ms": 30_000
  )

  consumer.subscribe(DT.topic)
  previous = nil

  until DT.key?(:done)
    consumer.poll(100)

    partitions = (consumer.assignment.to_h[DT.topic] || []).map(&:partition).sort

    if partitions != previous
      DT[:other_assignments] << partitions
      previous = partitions
    end
  end

  consumer.close
end

# Wait for the other member to own the whole topic before Karafka joins
sleep(0.1) until DT[:other_assignments].include?([0, 1])

2.times { |i| PRODUCER.produce_sync(topic: DT.topic, payload: "before-#{i}", partition: i) }

# First run: Karafka joins (this triggers the one and only rebalance in this spec), consumes
# from its partition and stops
start_karafka_and_wait_until(reset_status: true) do
  !DT[:consumed].empty?
end

# A leaving static member must not trigger a rebalance - give the group a moment to prove it
sleep(8)

baseline = DT[:other_assignments].dup

2.times { |i| PRODUCER.produce_sync(topic: DT.topic, payload: "after-#{i}", partition: i) }

consumed_before_restart = DT[:consumed].size

# Second run: the "new pod" of the same static member - must get the same partition back and
# resume consumption without rebalancing anything
start_karafka_and_wait_until(reset_status: true) do
  DT[:consumed].size > consumed_before_restart
end

DT[:done] = true
other.join

# Both shutdowns must be graceful and fast: no unsubscribe wait dance (Karafka skips it for
# static members on purpose) and no rebalance-related close blocking
assert_equal 2, DT[:stopping_at].size
assert_equal 2, DT[:stopped_at].size

DT[:stopping_at].zip(DT[:stopped_at]).each do |stopping, stopped|
  took = stopped - stopping

  assert took < 5, "static member shutdown expected to be immediate, took #{took}s"
end

# Neither the Karafka member leaving, nor its restarted "pod" re-joining is allowed to touch
# the other member assignments
assert_equal baseline, DT[:other_assignments], "no rebalance was expected on a rolling restart"

# The other member went empty -> whole topic -> one partition (Karafka joining) and stayed there
assert_equal [0, 1], DT[:other_assignments][1]
assert_equal 1, DT[:other_assignments].last.size

# Karafka must have consumed from the very same partition in both runs (assignment preserved
# across the restart)
karafka_partitions = DT[:consumed].map(&:first).uniq

assert_equal 1, karafka_partitions.size, "expected the same single partition across restarts"

# And it must have really consumed in both runs (before and after the rolling restart)
payloads = DT[:consumed].map(&:last)

assert payloads.any? { |payload| payload.start_with?("before-") }
assert payloads.any? { |payload| payload.start_with?("after-") }
