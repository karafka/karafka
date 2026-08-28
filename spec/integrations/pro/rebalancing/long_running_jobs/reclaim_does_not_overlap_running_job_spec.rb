# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Regression guard for the scenario explored in issue #3227.
#
# When an LRJ is running and its partition is revoked and then re-assigned to the SAME process (eager
# rebalance), one might expect the old (now-revoked) still-running copy and the new copy to run
# concurrently, with the old copy resuming a partition the new copy now owns. In practice they DO NOT
# overlap - the reclaim is serialized: the partition stays paused across the same-consumer
# reassignment, so the new copy cannot be scheduled until the old copy finishes and resumes the
# partition. That resume is load-bearing (it lifts the pause so the reclaim can proceed), not a bug.
#
# This spec reproduces that exact scenario and asserts the serialization holds:
#   * the same partition is never processed by two consumer instances at once, and
#   * no partition is resumed while a consume for it is still in-flight (i.e. the revoked copy never
#     resumes a partition a newer copy owns).
# It passes on master and would fail if a change (e.g. isolating pause trackers per assignment
# generation) broke the serialization and let the two copies overlap.

setup_karafka do |config|
  config.concurrency = 5
  config.shutdown_timeout = 60_000
end

# Tracks consumer instances currently inside `#consume` per partition, so we can assert that (a) no
# two of them overlap and (b) no resume fires while one is still running.
module Inflight
  MUTEX = Mutex.new
  ACTIVE = Hash.new { |h, k| h[k] = [] }
  MAX = Hash.new(0)

  class << self
    def enter(partition, oid)
      MUTEX.synchronize do
        ACTIVE[partition] << oid
        MAX[partition] = [MAX[partition], ACTIVE[partition].size].max
      end
    end

    def leave(partition, oid)
      MUTEX.synchronize { ACTIVE[partition].delete(oid) }
    end

    def active?(partition)
      MUTEX.synchronize { !ACTIVE[partition].empty? }
    end

    def max(partition)
      MUTEX.synchronize { MAX[partition] }
    end
  end
end

Karafka.monitor.subscribe("client.resume") do |event|
  DT[:premature_resumes] << event[:partition] if Inflight.active?(event[:partition])
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    Inflight.enter(partition, object_id)
    DT["ids-#{partition}"] << object_id

    # Long enough to still be running across the rebalance and while the partition is reclaimed
    sleep(10)

    # Success path -> LRJ#handle_after_consume resumes the partition (unconditionally, even when
    # revoked). This is the resume that lets the reclaimed partition continue.
    mark_as_consumed!(messages.last) unless revoked?
  ensure
    Inflight.leave(partition, object_id)
  end

  def revoked
    DT[:revoked] << true
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
    long_running_job true
  end
end

# Keep both partitions fed
Thread.new do
  loop do
    produce(DT.topic, "1", partition: 0)
    produce(DT.topic, "1", partition: 1)

    sleep(0.5)
  rescue
    nil
  end
end

# Both partitions must be actively processed before we trigger the rebalance
def got_both?
  DT["ids-0"].any? && DT["ids-1"].any?
end

# A second consumer in the SAME group steals one partition, forcing an eager rebalance. The
# partition Karafka KEEPS is revoked-and-reassigned to the same process while its LRJ still sleeps.
consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(0.1) until got_both?
  # Let the in-flight LRJs settle into their sleep so they are mid-job when the rebalance hits
  sleep(2)

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << message.partition
    consumer.store_offset(message)
    consumer.commit(nil, false)

    break if DT[:stop].any?
  end

  consumer.close
end

start_karafka_and_wait_until do
  # Run until the kept partition was reclaimed by a 2nd instance and processed again afterwards -
  # i.e. well past the old copy's wake-up, so any overlap/premature resume would already have shown.
  DT[:jumped].any? &&
    [0, 1].any? { |p| DT["ids-#{p}"].uniq.size >= 2 && DT["ids-#{p}"].size >= 3 }
end

DT[:stop] << true
other.join

jumped_partition = DT[:jumped].first
kept_partition = jumped_partition.zero? ? 1 : 0

# Sanity: we actually reproduced the scenario (the kept partition was reclaimed by a new instance)
assert DT[:jumped].any?
assert(
  DT["ids-#{kept_partition}"].uniq.size >= 2,
  "kept partition #{kept_partition} was not re-picked-up by a new consumer instance"
)

# Serialization invariant: a partition is never processed by two instances at the same time
assert_equal 1, Inflight.max(0)
assert_equal 1, Inflight.max(1)

# And the revoked copy never resumes a partition while a consume for it is still in-flight
assert(
  DT[:premature_resumes].empty?,
  "premature resume(s): #{DT[:premature_resumes].tally.inspect}"
)
