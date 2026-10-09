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

# Pins the read_uncommitted half of the compensated lag on a transactional topic.
#
# The refresh forwards the consumer's own `isolation.level` to `ListOffsets`. A read_uncommitted
# consumer will see uncommitted messages, so for it `:latest` resolves to the high watermark and,
# while a transaction is held OPEN on a paused partition, the compensated lag counts the
# uncommitted messages. `transactional_lso_spec.rb` pins the read_committed half. If the isolation
# level mapping or forwarding in `Connection::ConsumerGroups::Client` regresses to always reading
# committed, the lag stays at the last stable offset and this spec fails.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.kafka[:"isolation.level"] = "read_uncommitted"
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
  # Wait until the compensated lag has picked up the in-flight transaction, but give up after enough
  # samples so a regression fails fast. Always release the held transaction on exit, otherwise the
  # producer close would block on the open transaction.
  ready = DT.key?(:open) && (DT[:lags].any? { |lag| lag >= OPEN } || DT[:lags].size >= 90)
  DT[:measured] = true if ready
  ready
end

transactional_producer.close

# The compensated lag reflects the high watermark, so the in-flight transaction is counted
assert DT[:lags].max >= OPEN, "expected the in-flight transaction to be counted, got max #{DT[:lags].max}"
