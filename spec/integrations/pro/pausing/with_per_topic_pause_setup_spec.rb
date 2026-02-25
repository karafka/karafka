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

# When customizing the error pausing strategy, each topic should obey its own limitations

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.pause.timeout = 1_000
  config.pause.max_timeout = 10_000
  config.pause.with_exponential_backoff = false
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[messages.metadata.topic.to_s] << Time.now.to_f

    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
    pause(
      timeout: 100,
      max_timeout: 2_000,
      with_exponential_backoff: true
    )
  end

  topic DT.topics[2] do
    consumer Consumer
    pause(
      timeout: 5_000,
      max_timeout: 5_000,
      with_exponential_backoff: false
    )
  end
end

3.times { |i| produce(DT.topics[i], "0") }

start_karafka_and_wait_until do
  DT.data.size >= 3 && DT.data.all? { |_, v| v.size >= 5 }
end

previous = nil

DT[DT.topics[0]].each do |time|
  unless previous
    previous = time
    next
  end

  diff = time - previous

  assert diff >= 1, diff
  assert diff <= 5, diff

  previous = time
end

previous = nil

DT[DT.topics[1]].each do |time|
  unless previous
    previous = time
    next
  end

  diff = time - previous

  assert diff >= 0.1, diff
  assert diff <= 5, diff

  previous = time
end

previous = nil

DT[DT.topics[2]].each do |time|
  unless previous
    previous = time
    next
  end

  diff = time - previous

  assert diff >= 5, diff

  previous = time
end
