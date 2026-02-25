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

# When given partition is lost involuntary, we still should have last info
# In Pro despite extra option, should behave same as in OSS when no forced required

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Make sure we have insights at all
    return pause(messages.first.offset, 1_000) unless insights?

    DT[:running] << true
    DT[0] << insights?
    sleep(15)
    DT[0] << insights?
  end

  def revoked
    DT[:revoked] = true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].size >= 2 && DT.key?(:revoked)
end

assert DT[0].all?
