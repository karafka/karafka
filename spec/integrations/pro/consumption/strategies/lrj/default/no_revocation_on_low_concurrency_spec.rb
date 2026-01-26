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

# When running LRJ with low concurrency and many LRJ topics, we should not be kicked out of the
# consumer group after reaching the interval. Pausing should happen prior to processing and it
# should ensure that all new LRJ topics and partitions assigned are paused even when there are no
# available workers to do the work.

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(15)

    DT[:work] << messages.metadata.topic
  end

  def revoked
    DT[:revoked] << true
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
  end

  topic DT.topics[1] do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topics[0], DT.uuids(5))
produce_many(DT.topics[1], DT.uuids(5))

start_karafka_and_wait_until do
  DT[:work].uniq.size >= 2
end

# There should be no forced revocation as we should not reach the max poll
assert DT[:revoked].empty?
