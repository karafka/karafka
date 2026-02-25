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

# When there is a rebalance and we get the partition back, we should start consuming with a new
# consumer instance. We should use one before and one after we got the partition back.

setup_karafka do |config|
  config.concurrency = 4
  config.initial_offset = "latest"
end

class Consumer < Karafka::BaseConsumer
  def consume
    # We should never try to consume new batch with a revoked consumer
    # This is just an extra test to make sure things work as expected
    exit! 5 if revoked?

    partition = messages.metadata.partition

    DT["#{partition}-object_ids"] << object_id

    messages.each do |message|
      return unless mark_as_consumed!(message)
    end

    sleep 1
  end

  def revoked
    DT[:revoked] << true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
  end
end

Thread.new do
  loop do
    2.times do
      produce(DT.topic, "1", partition: 0)
      produce(DT.topic, "1", partition: 1)
    end

    sleep(0.5)
  rescue
    nil
  end
end

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

# This part makes sure we do not run rebalance until karafka got both partitions work to do
def got_both?
  DT["0-object_ids"].uniq.size >= 1 &&
    DT["1-object_ids"].uniq.size >= 1
end

other = Thread.new do
  sleep(0.1) until got_both?

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << message

    consumer.store_offset(message)
    consumer.commit(nil, false)

    next unless DT[:jumped].size >= 20

    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  other.join &&
    got_both? &&
    DT["0-object_ids"].uniq.size >= 2 &&
    DT["1-object_ids"].uniq.size >= 2
end

# Since there are two rebalances here, one of those may actually have 3 ids, that's why we check
# that it is two or more
assert DT.data["0-object_ids"].uniq.size >= 2
assert DT.data["1-object_ids"].uniq.size >= 2
assert !DT[:revoked].empty?
