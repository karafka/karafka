# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When using the Long Running Job feature, in case partition is lost during the processing, after
# partition is reclaimed, process should pick it up and continue. It should not hang in the pause
# state forever.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(15)

    DT[messages.first.partition] << messages.first.offset

    raise
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
  end
end

other = Thread.new do
  sleep(10)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << [message.partition, message.offset]
    sleep 15
    consumer.store_offset(message)
    break
  end

  consumer.commit(nil, false)

  consumer.close
end

SAMPLE_PARTITIONS = [0, 1].freeze

Thread.new do
  loop do
    produce(DT.topic, '1', partition: SAMPLE_PARTITIONS.sample)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 3 &&
    DT[1].size >= 3
end

other.join

lost = DT[:jumped][0][0]
not_lost = lost == 0 ? 1 : 0

assert_equal [0], DT[not_lost].uniq
assert DT[not_lost].size >= 3
assert_equal [0, 1], DT[lost].uniq
