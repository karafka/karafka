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

# Pins the transactional-topic behaviour of the compensated lag.
#
# The refresh queries end offsets via the batched `ListOffsets` admin API. As of karafka-rdkafka
# 0.30.0 that call honours the forwarded isolation level, so for a read_committed consumer
# `:latest` resolves to the last stable offset - the same reference `query_watermark_offsets` used.
# So while a transaction is held OPEN on a paused partition, the compensated lag reflects the last
# stable offset and excludes the uncommitted messages a read_committed consumer will never see.
#
# This spec pins that behaviour: with a large in-flight transaction the compensated lag stays put
# and does not grow to include it. Until karafka-rdkafka 0.30.0 `ListOffsets` silently ignored the
# isolation level and resolved `:latest` to the high watermark, so this lag transiently overstated
# by the number of uncommitted messages; if a future change reverts to that, this spec will fail -
# update the docs in `Fetcher`, `Connection::ConsumerGroups::Client#read_partition_offsets` and the
# CHANGELOG.

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
  # Collect enough lag samples while the transaction is held open to prove the lag does not creep
  # up towards the in-flight size. Always release the held transaction on exit, otherwise the
  # producer close would block on the open transaction.
  ready = DT.key?(:open) && DT[:lags].size >= 45
  DT[:measured] = true if ready
  ready
end

transactional_producer.close

# The compensated lag reflects the last stable offset, so the in-flight transaction is excluded and
# the lag stays near zero. A high-watermark result would grow to roughly the open-transaction size.
assert DT[:lags].max < OPEN - 10, "expected the in-flight transaction to be excluded, got max #{DT[:lags].max}"
