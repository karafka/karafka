# frozen_string_literal: true

# The KIP-848 counterpart of rebalancing/stuck_rebalance_forceful_shutdown_spec.rb showing that
# the new consumer group protocol mitigates the forceful shutdowns caused by rebalances stuck
# for longer than `shutdown_timeout`.
#
# The hostile conditions are the same: another group member takes over one of our partitions
# and never polls, so its part of the reassignment never finishes. Under the classic protocol
# such a member wedges the whole group (everyone waits on the join barrier until the offender
# gets fenced out after its `max.poll.interval.ms`) and on affected librdkafka versions a
# consumer closed during that window blocks inside `rd_kafka_consumer_close`, exceeding
# `shutdown_timeout` and ending in a forceful termination.
#
# Under KIP-848 the reconciliation is broker-driven and per-member: there is no group-wide
# barrier a non-cooperating member could wedge and no rebalance state the consumer close would
# have to wait for. The stalling member delays only its own partition takeover, while our
# shutdown mid-reconciliation stays fast and graceful.

setup_karafka(consumer_group_protocol: true) do |config|
  # Explicit (it is also the suite default) as this spec is about not reaching this timeout
  # despite the unresolved reassignment
  config.shutdown_timeout = 30_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << messages.metadata.partition
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

produce(DT.topic, "1", partition: 0)
produce(DT.topic, "1", partition: 1)

# Fires when the broker takes one of our partitions to reassign it to the stalling member -
# from that moment the reassignment is in-flight and cannot finish (the staller never polls)
Karafka.monitor.subscribe("rebalance.partitions_revoked") do |_event|
  DT[:revoked_at] = Time.now.to_f unless DT.key?(:revoked_at)
end

start_karafka_and_wait_until do
  if DT[:consumed].empty?
    false
  else
    unless DT.key?(:staller_started)
      staller = Rdkafka::Config.new(
        Karafka::Setup::AttributesMap.consumer(
          "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
          "group.id": Karafka::App.routes.first.id,
          "group.protocol": "consumer"
        )
      ).consumer

      # Joins the group (KIP-848 members join via background heartbeats, no polling needed) but
      # never polls, so it never activates the partition the broker routes to it
      staller.subscribe(DT.topic)

      # Keep the reference alive so it is not garbage collected mid-spec (finalizers would close
      # it and let the reassignment finish)
      DT[:stallers] << staller
      DT[:staller_started] = true
    end

    # Initiate the shutdown once our partition got revoked for the staller and its takeover
    # hangs (2 extra seconds is well beyond the broker-side reconciliation heartbeats cadence)
    if DT.key?(:revoked_at) && (Time.now.to_f - DT[:revoked_at]) > 2
      DT[:stop_requested_at] = Time.now.to_f
      true
    else
      false
    end
  end
end

shutdown_took = Time.now.to_f - DT[:stop_requested_at]

# The revocation towards the staller must have really happened prior to the shutdown
assert DT.key?(:revoked_at)

# Shutdown happened mid unresolved reassignment and still must be quick - way below both the
# 30s `shutdown_timeout` and the staller fencing time. Any close-time hang comparable with the
# classic protocol behavior would exceed this
assert shutdown_took < 15, "graceful shutdown expected to be quick, took #{shutdown_took}s"

# Close the staller in a bounded way (it has a pending never-served assignment)
closer = Thread.new { DT[:stallers].first.close }
closer.join(10) || closer.kill
