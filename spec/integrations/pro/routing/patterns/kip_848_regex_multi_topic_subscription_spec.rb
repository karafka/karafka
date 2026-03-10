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

# When using the KIP-848 consumer group protocol, regex evaluation is done broker-side using the
# RE2/J engine (Google RE2). Unlike the classic protocol (which used libc regex locally via
# librdkafka), RE2/J requires the regex to match the complete topic name.
#
# This means that a Karafka pattern defined as pattern(/topic/) produces the subscription string
# "^topic". With libc (classic protocol), this would match "topic-1" via prefix matching, but with
# RE2/J (consumer protocol), it requires a full-string match, so "topic-1" would NOT match.
#
# The correct approach is pattern(/topic.*/) which produces "^topic.*" and matches all topics
# starting with "topic" under both protocols.
#
# This test validates that a pattern using the proper .* wildcard suffix correctly matches
# multiple topics sharing a common prefix when the consumer group protocol is active.

TOPIC1 = "#{DT.topic}-1"
TOPIC2 = "#{DT.topic}-2"

setup_karafka(consumer_group_protocol: true) do |config|
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.raw_payload
    end
  end
end

# Use pattern(/#{DT.topic}.*/) which produces the subscription string "^<topic>.*"
# The .* suffix is critical for the consumer protocol - without it, RE2/J would require the regex
# to match the complete topic name, and "^<topic>" alone would not match "<topic>-1" or "<topic>-2"
draw_routes(create_topics: false) do
  pattern(/#{DT.topic}.*/) do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  unless @created
    sleep(5)

    produce_many(TOPIC1, DT.uuids(5))
    produce_many(TOPIC2, DT.uuids(5))
    @created = true
  end

  DT.key?(TOPIC1) && DT.key?(TOPIC2)
end

assert_equal 5, DT[TOPIC1].size
assert_equal 5, DT[TOPIC2].size
