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

# Karafka should use more than one thread to consume independent topics with the pro scheduler
# Here we just aim to ensure, that we schedule all the jobs and that things operate as expected

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    # This will simulate, that the thread is busy in a bit random way, so more worker threads can
    # be occupied
    sleep(0.1)

    messages.each do
      DT[topic.name] << Thread.current.object_id
    end
  end
end

draw_routes(create_topics: false) do
  DT.topics.first(10).each do |topic_name|
    topic topic_name do
      consumer Consumer
    end

    produce_many(topic_name, DT.uuids(10))
  end
end

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 100
end

# All workers should be in use
assert_equal 10, DT.data.keys.size
# All workers consumers should consume same number of messages
assert_equal 10, DT.data.values.flatten.uniq.size
assert_equal 10, DT.data.values.map(&:size).uniq.first
