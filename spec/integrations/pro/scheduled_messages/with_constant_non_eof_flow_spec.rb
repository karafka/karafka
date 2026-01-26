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

# When there are constantly published messages, the state should be switched within acceptable time
# after the messages reach the current time. This should happen even when EOF is not triggered.

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

enveloped = Karafka::Pro::ScheduledMessages.schedule(
  message: {
    topic: DT.topics[1],
    payload: {}.to_json
  },
  epoch: Time.now.to_i + 100_000,
  envelope: {
    topic: DT.topics[0],
    key: SecureRandom.uuid
  }
)

Karafka.producer.produce_many_sync(
  Array.new(10_000) { enveloped }
)

Thread.new do
  loop do
    Karafka.producer.produce_sync(enveloped)
  end
rescue WaterDrop::Errors::ProducerClosedError
  nil
end

# Let it publish enough data
sleep(10)

start_karafka_and_wait_until do
  last = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).last

  next false unless last

  last.payload[:state] == "loaded"
end
