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

# When LRJ jobs are in the processing queue prior to being picked by the workers and those LRJ
# jobs get revoked, the job should not run.

setup_karafka do |config|
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.last.partition
    sleep(5) while DT[:rebalanced].empty?
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(20), partition: 0)
produce_many(DT.topic, DT.uuids(20), partition: 1)

start_karafka_and_wait_until do
  if DT.key?(0)
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    5.times { consumer.poll(1_000) }
    consumer.close

    DT[:rebalanced] << true

    sleep(1)

    true
  else
    false
  end
end

assert_equal 1, DT[0].uniq.size
