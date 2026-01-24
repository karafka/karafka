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

# When using the filtering API, we can use a persistent storage to transfer the pause over the
# rebalance to the same or other processes.
#
# Here we do not use cooperative.sticky to trigger a revocation during a pause and we continue
# the pause until its end after getting the assignment back.

# Fake DB layer
#
# We do not have to care about topics and partitions because for spec like this we use one
# partition

class DbPause
  class << self
    def pause(offset, time)
      DT[:pause] << [offset, time]
    end

    def fetch
      DT.key?(:pause) ? DT[:pause].last : false
    end
  end
end

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:times] << Time.now.to_f
    DT[:firsts] << messages.first.offset

    persistent_pause(
      messages.first.offset,
      10_000
    )
  end

  def persistent_pause(offset, pause_ms)
    DbPause.pause(offset, Time.now + (pause_ms / 1_000))
    pause(offset, pause_ms)
  end
end

class PauseManager < Karafka::Pro::Processing::Filters::Base
  def initialize(topic, partition)
    super()
    @topics = topic
    @partition = partition
  end

  def apply!(messages)
    messages.clear if timeout.positive?
  end

  def applied?
    true
  end

  def action
    timeout.positive? ? :pause : :skip
  end

  def cursor
    ::Karafka::Messages::Seek.new(
      @topic,
      @partition,
      DbPause.fetch.first
    )
  end

  def timeout
    return 0 unless DbPause.fetch

    timeout = DbPause.fetch.last - Time.now
    timeout.negative? ? 0 : timeout * 1_000
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(topic, partition) { PauseManager.new(topic, partition) }
  end
end

consumer = setup_rdkafka_consumer

# Trigger rebalance
other =  Thread.new do
  sleep(0.1) until DT.key?(:times)

  consumer.subscribe(DT.topic)
  consumer.each { break }

  consumer.close
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))
  sleep(0.5)

  DT[:times].size >= 2
end

other.join

assert_equal 2, DT[:times].size
assert(DT[:times].last - DT[:times].first >= 10)
assert_equal [0], DT[:firsts].uniq
