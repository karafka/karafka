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

# Karafka should allow us to use throttling engine to implement delayed jobs

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.offset, Time.now.utc]
    end
  end
end

class DelayThrottler < Karafka::Pro::Processing::Filters::Base
  include Karafka::Core::Helpers::Time

  attr_reader :cursor

  def initialize
    super
    # 5 seconds
    @min_delay = 5
  end

  def apply!(messages)
    @applied = false
    @cursor = nil

    now = float_now

    messages.delete_if do |message|
      @applied = (now - message.timestamp.to_f) < @min_delay

      @cursor = message if @applied && @cursor.nil?

      @applied
    end
  end

  def applied?
    @applied
  end

  def action
    if applied?
      (timeout <= 0) ? :seek : :pause
    else
      :skip
    end
  end

  def timeout
    timeout = (@min_delay * 1_000) - ((float_now - @cursor.timestamp.to_f) * 1_000)
    [timeout, 0].max
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(->(*) { DelayThrottler.new })
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  sleep(15)
end
