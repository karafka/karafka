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

# Messages scheduled close in past should work without any issues

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

Thread.new do
  sleep(5)

  iteration = 0

  100.times do
    iteration += 1

    5.times do |round|
      enveloped = Karafka::Pro::ScheduledMessages.schedule(
        message: {
          topic: DT.topics[1],
          payload: {}.to_json
        },
        epoch: Time.now.to_i - (5 + round),
        envelope: {
          topic: DT.topics[0],
          key: "#{iteration}-#{Time.now.to_i}#{SecureRandom.uuid}",
          partition: 0
        }
      )

      Karafka.producer.produce_async(enveloped)
    end

    sleep(0.1)
  end
end

dispatched = nil

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 500)

  dispatched.size >= 500
end

assert_equal 500, dispatched.size
