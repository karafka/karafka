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

# Virtual partitions and long-running jobs should not have any problems working together

setup_karafka do |config|
  config.max_messages = 50
  config.max_wait_time = 1_000
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    # just a check that we have this api method included in the strategy
    collapsed?

    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)

    messages.each do |message|
      DT[:messages] << message.raw_payload
    end

    DT[:threads] << Thread.current.object_id
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

# We should use all the threads available to process data despite it coming from a single partition
assert_equal 5, DT.data[:threads].uniq.size

# We should not have any duplicated messages
assert_equal DT[:messages], DT[:messages].uniq

# We should have exactly as many as we expected
assert_equal 100, DT[:messages].size
