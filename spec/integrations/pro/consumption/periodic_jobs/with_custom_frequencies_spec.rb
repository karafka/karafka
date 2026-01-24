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

# We should be able to define custom frequencies and it should work.
# It should use defaults where nothing defined

setup_karafka do |config|
  config.max_messages = 1
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    DT[topic.name] << Time.now.to_f
  end
end

draw_routes do
  defaults do
    consumer Consumer
  end

  topic DT.topics[0] do
    # every 5 seconds (default tick interval)
    periodic true
  end

  topic DT.topics[1] do
    periodic interval: 100
  end

  topic DT.topics[2] do
    periodic interval: 1_000
  end
end

start_karafka_and_wait_until do
  DT.topics.first(3).all? do |name|
    DT[name].size >= 5
  end
end

[
  [4_900, 10_000],
  [100, 1_000],
  [1_000, 2_000]
].each_with_index do |(min, max), index|
  previous = nil

  DT[DT.topics[index]].each do |time|
    unless previous
      previous = time

      next
    end

    delta = ((time - previous) * 1_000).ceil

    assert delta >= min, [delta, min]
    assert delta <= max, [delta, max]

    previous = time
  end
end
