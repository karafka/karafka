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

# When Karafka consumes in the VP mode and error happens in any of the processing units we allow
# the rest to finish the work and we restart the processing from the first offset on a batch
# in a collapsed mode.
#
# This spec raises only one error once

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
  MUTEX = Mutex.new

  def consume
    messages.each { |message| DT[0] << message.raw_payload }
    DT[1] << object_id

    MUTEX.synchronize do
      next unless DT[2].empty?

      DT[2] << true

      raise StandardError
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  # We have 5 messages but we retry thus it needs to be minimum 6
  DT[0].size >= 6
end

assert DT[0].size >= 6, DT[0]
# It should parallelize work
assert_equal 1, DT[:errors].size
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal 'consumer.consume.error', DT[:errors].first[:type]
assert_equal 'error.occurred', DT[:errors].first.id
assert_equal 5, DT[0].uniq.size
