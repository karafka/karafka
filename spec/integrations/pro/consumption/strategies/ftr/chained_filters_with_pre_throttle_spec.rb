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

# We should be able to chain filters and to achieve expected processing flow
# In this scenario we will filter all odd offsets and we will make sure, we process data with
# a delay and with throttling used to make sure we do not process more than 5 messages per second
# We will throttle first and this will have impact on how many elements we will get into the
# consumer

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:counts] << messages.size
    DT[:times] << Time.now

    messages.each do |message|
      DT[:offsets] << message.offset
    end
  end
end

class OddRemoval < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil

    messages.delete_if do |message|
      !(message.offset % 2).zero?
    end
  end

  def action
    :skip
  end

  def applied?
    true
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    throttle(limit: 5, interval: 1_000)
    filter(->(*) { OddRemoval.new })
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(5))

  DT[:offsets].size > 50
end

# All offsets that we've processed should be even and in order
previous = -2

DT[:offsets].each do |offset|
  assert_equal previous + 2, offset
  previous = offset
end

# We should never have more than 3 messages in a batch because we first throttle on 5 and then
# filter so the best we can do is [0, 2, 4] or [8, 10, 12] etc out of the throttled set of 5.
assert(DT[:counts].all? { |count| count <= 3 })

# There should always be a delay on average in between batches
time_taken = DT[:times].last - DT[:times].first
average = (time_taken / DT[:counts].sum)
assert average >= 0.19, average

# Since we throttle on unfiltered set, we will always limit ourselves with throttle prior to
# filtering, which will mean, we pass less to consumer
assert (DT[:counts].sum / DT[:counts].size.to_f) < 3
