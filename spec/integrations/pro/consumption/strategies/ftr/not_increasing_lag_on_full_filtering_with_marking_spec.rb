# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we have a filter that rejects all (or most of) the data all the time, since we do mark
# as consumed, the offset will be stored. This means, that lag will not grow.

setup_karafka do |config|
  config.max_messages = 10
end

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  next unless event[:statistics]['topics'][DT.topic]
  next unless event[:statistics]['topics'][DT.topic]['partitions']
  next unless event[:statistics]['topics'][DT.topic]['partitions']
  next unless event[:statistics]['topics'][DT.topic]['partitions']['0']

  DT[:lags] << event[:statistics]['topics'][DT.topic]['partitions']['0']['consumer_lag']
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed(messages.last)
  end
end

class Skipper < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  # We allow one batch once to go so we get the first offset store
  def apply!(messages)
    if DT.key?(:done)
      @cursor = messages.last
      messages.clear
    else
      DT[:done] = true
    end
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

  def mark_as_consumed?
    true
  end

  # We mark in sync mode in this spec because we want to ensure that lag is refreshed asap for
  # reporting
  def marking_method
    :mark_as_consumed!
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

  DT[:lags].size >= 100
end

# Expect lag to grow but then go lower when marking happens
previous = nil
decrease = false

DT[:lags].each do |current|
  unless previous
    previous = current

    next
  end

  decrease = true if previous > current

  previous = current
end

assert decrease

assert DT[:lags].include?(0)
