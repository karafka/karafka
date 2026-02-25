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

# Using manual offset management under rebalance and error happening, we should start from the
# last place that we were, even when there were many batches down the road and no checkpointing

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    @runs ||= 0

    messages.each do |message|
      DT[:offsets] << message.offset
    end

    @runs += 1

    return unless @runs == 4

    # The -1 will act as a divider so it's easier to spec things
    DT[:split] << DT[:offsets].size
    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

Thread.new do
  loop do
    produce(DT.topic, "1", partition: 0)

    sleep(0.1)
  rescue
    nil
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= 17
end

split = DT[:split].first

before = DT[:offsets][0..(split - 1)]
after = DT[:offsets][split..100]

# It is expected to reprocess all since consumer was created even when there are more batches
assert_equal [], before - after
