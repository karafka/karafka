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

# When dispatch of a given batch / message crashes, we should retry the same
# This gives us at-least once in case of non-transactional consumer and exactly-once in case of
# the transactional one

setup_karafka(allow_errors: %w[consumer.consume.error consumer.tick.error])

class TrackConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:keys] << message.key
    end
  end
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    consumer TrackConsumer
  end
end

proxies = Array.new(10) do |i|
  message = {
    topic: DT.topics[1],
    key: i.to_s,
    payload: 'payload'
  }

  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    # We give the consumer enough time to start working
    epoch: Time.now.to_i + (i * 5),
    envelope: { topic: DT.topics[0], partition: 0 }
  )
end

Karafka.producer.produce_many_sync(proxies)

# This middleware will crash after 2 dispatches to simulate dispatch crash in sync producer
class Crasher
  def call(message)
    # Don't crash on async state reporting, just proxy dispatches
    return message if message[:key].end_with?('_state')

    DT[:totals] << 1

    raise if DT[:totals].size == 3

    message
  end
end

Karafka.producer.middleware.append(Crasher.new)

start_karafka_and_wait_until(sleep: 1) do
  DT[:keys].size >= 6
end

# All should be delivered and no skip on error
assert_equal DT[:keys][0..5].map(&:to_i), (0..5).to_a
