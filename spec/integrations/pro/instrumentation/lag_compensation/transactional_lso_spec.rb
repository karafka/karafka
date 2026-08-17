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

# Documents a KNOWN EDGE CASE of the transactional-topic behaviour.
#
# The refresh queries end offsets via the batched `ListOffsets` admin API. Unlike the per-partition
# `query_watermark_offsets` it replaced, `ListOffsets` resolves `:latest` to the high watermark
# even for a read_committed consumer. So while a transaction is held OPEN on a paused partition, the
# compensated lag reflects the high watermark and includes the uncommitted messages a read_committed
# consumer will never see - transiently overstating the lag until the transaction resolves.
#
# This spec pins that documented behaviour: with a large in-flight transaction the compensated lag
# grows to include it. If a future change makes the refresh honour the last stable offset here (lag
# would then reflect only the committed messages) this spec will fail - update the docs in
# `Fetcher`, `Connection::Client#read_partition_offsets` and the CHANGELOG when it does.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.kafka[:"isolation.level"] = "read_committed"
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

OPEN = 30

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.last)

    return if DT.key?(:paused)

    pause(messages.last.offset, 1_000_000)
    DT[:paused] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:lags] << partition_values["consumer_lag"]
    end
  end
end

draw_routes(Consumer)

# A non-transactional seed message so the consumer has something to consume and then pause on
produce_many(DT.topic, DT.uuids(1))

transactional_producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = {
    "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
    "transactional.id": SecureRandom.uuid
  }
end

# Hold a large transaction open for the whole measurement: the high watermark jumps by ~OPEN while
# the last stable offset stays pinned behind it. Aborted at the end purely to release it cleanly.
Thread.new do
  sleep(0.1) until DT.key?(:paused)

  begin
    transactional_producer.transaction do
      OPEN.times { transactional_producer.produce_async(topic: DT.topic, payload: DT.uuid) }
      DT[:open] = true

      sleep(0.1) until DT.key?(:measured)

      raise(WaterDrop::AbortTransaction)
    end
  rescue WaterDrop::AbortTransaction
    nil
  end
end

start_karafka_and_wait_until do
  # Exit once the in-flight transaction is clearly reflected, with a sample-count fallback so a
  # regression (or the feature being off) fails fast instead of hanging. Always release the held
  # transaction on exit, otherwise the producer close would block on the open transaction.
  ready = DT.key?(:open) &&
    (DT[:lags].max.to_i >= (OPEN - 10) || DT[:lags].size >= 45)
  DT[:measured] = true if ready
  ready
end

transactional_producer.close

# Known edge case: the compensated lag includes the in-flight transaction (high watermark), so it
# grows to roughly the open-transaction size. A last-stable-offset result would stay near zero.
assert DT[:lags].max >= OPEN - 10, "expected the in-flight transaction to be included, got max #{DT[:lags].max}"
