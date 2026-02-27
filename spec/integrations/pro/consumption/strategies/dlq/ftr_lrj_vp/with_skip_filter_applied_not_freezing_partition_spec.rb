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

# When DLQ + FTR + LRJ + VP are combined and a filter returns applied? true with action :skip,
# the partition should NOT become permanently frozen.

setup_karafka do |config|
  config.max_messages = 5
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class SkipFilter < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    @applied = false
    @cursor = nil

    messages.delete_if do |message|
      if message.raw_payload.include?("odd")
        @applied = true
        @cursor = message
        true
      else
        false
      end
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:processed] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    filter ->(*) { SkipFilter.new }
    virtual_partitions(
      partitioner: ->(_msg) { rand(2) }
    )
  end
end

payloads = Array.new(20) { |i| i.even? ? "even-#{i}" : "odd-#{i}" }
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:processed].size >= 10
end

even_offsets = (0...20).select(&:even?).to_a
assert_equal even_offsets, DT[:processed].sort
