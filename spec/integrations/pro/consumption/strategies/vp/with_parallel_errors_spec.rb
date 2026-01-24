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

# When Karafka consumes in the VP mode and many errors happen in many of the processing units,
# we we should continue and we should restart the processing from the first offset on a batch in
# a collapsed mode until the collective offset is passed

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    if !@raised && messages.size > 1
      @raised = true
      raise StandardError
    end

    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

class Iterator
  def step
    @step ||= -1

    (@step += 1) % 10
  end
end

ITER = Iterator.new

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_) { ITER.step }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal 10, DT[:errors].size, DT[:errors].size

previous = nil

## Check that no messages are skipped
DT[0].flatten.sort.uniq.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
