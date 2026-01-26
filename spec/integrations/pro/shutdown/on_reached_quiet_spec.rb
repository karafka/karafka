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

# When we have reached quiet state, we should still be subscribed to what we had

setup_karafka

produce(DT.topic, "1")

class Consumer < Karafka::BaseConsumer
  def consume
    DT[SecureRandom.uuid] = true
    sleep(1)
  end
end

draw_routes(create_topics: false) do
  5.times do |i|
    consumer_group "gr#{i}" do
      topic DT.topic do
        consumer Consumer
      end
    end
  end
end

Thread.new do
  sleep(0.1) until DT.data.keys.size >= 5

  # Move to quiet
  Karafka::Server.quiet

  # Wait and make sure we are polling
  10.times do
    sleep(1)
    assert Karafka::Server.listeners.none?(&:stopped?)
    assert Karafka::Server.listeners.none?(&:stopping?)
  end

  assert Karafka::Server.listeners.all?(&:quiet?)

  Karafka::Server.stop
end

start_karafka_and_wait_until do
  false
end
