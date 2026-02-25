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

# We should be able to use `#failing?` to detect, that part of our work has already failed and
# that our current set of VPs will collapse.
#
# This can be used to stop processing when we know, it is going to be re-processed again

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

# Ensures, that we don't process at all unless we have at least 10 messages
# This eliminates the case of running a single virtual partition
class Buffer < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    @applied = messages.size < 10

    return unless @applied

    @cursor = messages.first
    messages.clear
  end

  def action
    if applied?
      :pause
    else
      :skip
    end
  end

  def timeout
    250
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    if messages.first.offset.zero?
      sleep(0.1)

      raise StandardError
    else
      sleep(2)
    end

    if failing?
      DT[:failing] << true
    else
      DT[:ended] << true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { Buffer.new }
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload.to_i % 10 }
    )
  end
end

produce_many(DT.topic, Array.new(100, &:to_s))

start_karafka_and_wait_until do
  DT[:failing].size >= 9
end

assert DT[:ended].empty?
