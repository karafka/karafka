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

# When LRJ job uses a critical section, the revocation job should wait and not be able to
# run its critical section alongside.

setup_karafka do |config|
  config.concurrency = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    synchronize do
      DT[:started] = Time.now.to_f
      sleep(15)
      DT[:stopped] = Time.now.to_f
    end
  end

  def revoked
    DT[:before_revoked] = Time.now.to_f

    synchronize do
      DT[:revoked] = Time.now.to_f
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  if DT.key?(:started)
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    5.times { consumer.poll(1_000) }
    consumer.close

    sleep(1)

    true
  else
    false
  end
end

lock_range = (DT[:started]..DT[:stopped])

# Make sure that synchronization block works as expected
assert lock_range.include?(DT[:before_revoked])
assert !lock_range.include?(DT[:revoked])
assert DT[:revoked] > DT[:stopped]
