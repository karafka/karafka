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

# When all messages are filtered out and the filter implements `mark_as_consumed?` returning true,
# Karafka should mark the offset at the cursor position (the last filtered message) so that
# processing can continue from the correct position. This test verifies that:
# 1. All messages are successfully filtered out
# 2. The offset is correctly stored at the cursor (the last message that was filtered)
# 3. Consumer lag does not grow indefinitely

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Should not happen, all should be filtered
    raise
  end
end

class AllMessagesFilter < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    messages.each { DT[:messages] << true }

    # Store the last message as cursor - this is the last message that will be filtered
    # and where the offset should be marked
    @cursor = messages.last if messages.any?

    # Filter out all messages
    messages.clear
  end

  def applied?
    true
  end

  def action
    :skip
  end

  def timeout
    0
  end

  # Tell Karafka to mark the cursor position when all messages are filtered
  def mark_as_consumed?
    true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { AllMessagesFilter.new }
    manual_offset_management true
  end
end

# Produce messages
elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

assert_equal 100, fetch_next_offset(DT.topic)
