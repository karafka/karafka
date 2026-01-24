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

# When we cancel future already loaded daily message, it should not go out

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

message = {
  topic: DT.topics[1],
  key: '0',
  payload: 'payload'
}

proxy = Karafka::Pro::ScheduledMessages.schedule(
  message: message,
  # We give the consumer enough time to start working
  epoch: Time.now.to_i + 15,
  envelope: { topic: DT.topics[0], partition: 0 }
)

Karafka.producer.produce_sync(proxy)

start_karafka_and_wait_until(sleep: 1) do
  state = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).first

  next unless state

  if state.payload[:daily].first.last > 0 && !@cancelled
    @cancelled = true

    cancel = Karafka::Pro::ScheduledMessages.cancel(
      key: proxy[:key],
      envelope: { topic: DT.topics[0], partition: 0 }
    )

    Karafka.producer.produce_sync(cancel)
  end

  @cancelled && state.payload[:daily].first.last.zero?
end

# Nothing should have been dispatched
assert_equal Karafka::Admin.read_topic(DT.topics[1], 0, 1), []
