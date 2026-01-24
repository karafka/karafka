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

# Karafka should allow for usage of custom throttlers per topic

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.offset
    end
  end
end

# This is a funny throttler because it will always allow only one message and if more, it will
# throttle.
class BaseThrottler < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil

    i = -1

    messages.delete_if do |message|
      i += 1

      @applied = i > 0

      @cursor = message if @applied && @cursor.nil?

      next true if @applied

      false
    end
  end

  def action
    if applied?
      timeout.zero? ? :seek : :pause
    else
      :skip
    end
  end

  def applied?
    @applied
  end

  def timeout
    self.class.to_s[-1].to_i * 1_000
  end
end

MyThrottler1 = Class.new(BaseThrottler)
MyThrottler10 = Class.new(BaseThrottler)

draw_routes do
  topic DT.topics[0] do
    consumer Consumer1
    filter(->(*) { MyThrottler1.new })
  end

  topic DT.topics[1] do
    consumer Consumer2
    filter(->(*) { MyThrottler10.new })
  end
end

2.times do |i|
  elements = DT.uuids(100)
  produce_many(DT.topics[i], elements)
end

start_karafka_and_wait_until do
  sleep(20)
end

assert DT[1].size > DT[0].size * 2
