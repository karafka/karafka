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

# When we create a filter that just skips all the messages and does not return the cursor message,
# we should never seek and just go on with incoming messages

class Listener
  def on_filtering_seek(_)
    DT[:seeks] << true
  end

  def on_filtering_throttled(_)
    DT[:thr] << true
  end
end

setup_karafka do |config|
  config.max_messages = 10
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

class Skipper < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    messages.each { |message| DT[:offsets] << message.offset }
    messages.clear
  end

  def applied?
    true
  end

  def action
    :skip
  end

  def cursor
    nil
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { Skipper.new }
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))

  DT[:offsets].size >= 50
end

assert DT[0].empty?
assert DT[:seeks].empty?
assert DT[:thr].empty?

# Everything should be in order and no duplicates
previous = -1

DT[:offsets].each do |offset|
  assert_equal previous + 1, offset

  previous = offset
end
