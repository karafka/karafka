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

# Compensation honours the consumer isolation level. Under the default read_committed it queries
# the last stable offset, so aborted transactions (which advance the high watermark but not the
# LSO) never inflate the compensated lag. A large aborted batch followed by a small committed one
# must leave the compensated lag reflecting only the committed messages.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.kafka[:"isolation.level"] = "read_committed"
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

ABORTED = 30
COMMITTED = 5

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

Thread.new do
  sleep(0.1) until DT.key?(:paused)

  # Aborted batch: pushes the high watermark up by ~ABORTED, but the LSO does not move
  transactional_producer.transaction do
    ABORTED.times { transactional_producer.produce_async(topic: DT.topic, payload: DT.uuid) }
    raise(WaterDrop::AbortTransaction)
  end

  # Committed batch: advances the LSO by ~COMMITTED
  transactional_producer.transaction do
    COMMITTED.times { transactional_producer.produce_async(topic: DT.topic, payload: DT.uuid) }
  end

  DT[:produced] = true
end

start_karafka_and_wait_until do
  (DT.key?(:produced) && DT[:lags].max.to_i >= 2 && DT[:lags].size >= 18) || DT[:lags].size >= 40
end

transactional_producer.close

# Compensation reflects the committed messages (LSO moved), so the lag grows above the frozen zero
assert DT[:lags].max >= 2, "expected compensation from committed messages, got max #{DT[:lags].max}"
# ... but the aborted batch is excluded: read_committed uses the LSO, not the high watermark, so
# the lag stays far below the aborted count
assert DT[:lags].max <= 20, "aborted transaction inflated the lag (HWM not LSO), got max #{DT[:lags].max}"
