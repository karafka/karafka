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

# When running lrj, on revocation Karafka should change the revocation state even when there are
# no available slots for processing

setup_karafka do |config|
  config.max_messages = 5
  config.concurrency = 2
end

DT[:started] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    until revoked? || DT[:revoked].size >= 2
      sleep(0.1)
      DT[:started] << object_id
    end

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

produce(DT.topic, "0", partition: 0)
produce(DT.topic, "1", partition: 1)

start_karafka_and_wait_until do
  if DT[:started].size >= 2
    if DT[:rebalanced].empty?
      consumer = setup_rdkafka_consumer
      consumer.subscribe(DT.topic)
      5.times { consumer.poll(1_000) }
      consumer.close
      DT[:rebalanced] << true
    end

    DT[:revoked].size >= 2
  else
    false
  end
end

# No spec needed. If revocation would not happen as expected while all the threads are occupied,
# This would hang forever.
