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
# A pattern defined as pattern(/prefix/) produces the subscription string "^prefix". With the
# classic protocol, libc regex does partial/prefix matching, so "^prefix" would match "prefix-1".
# With the consumer protocol, RE2/J treats the regex as a full-string match, so "^prefix" only
# matches the literal topic "prefix" and NOT "prefix-1" or "prefix-2".
#
# This test validates that a pattern WITHOUT the .* wildcard suffix does NOT match topics that
# extend the prefix (e.g., "prefix-1", "prefix-2") when the consumer group protocol is active.
# No messages should be consumed because no topic named exactly "<prefix>" exists — only
# "<prefix>-1" and "<prefix>-2" exist, and RE2/J won't match them with "^<prefix>".

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

# Use pattern(/#{DT.topic}/) which produces the subscription string "^<topic>" (no .* suffix).
# Under the consumer protocol, RE2/J requires a full match, so "^<topic>" will NOT match
# "<topic>-1" or "<topic>-2". No partitions should be assigned.
draw_routes(create_topics: false) do
  pattern(/#{DT.topic}/) do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  unless @produced
    sleep(5)

    produce_many(TOPIC1, DT.uuids(5))
    produce_many(TOPIC2, DT.uuids(5))
    @produced = true
  end

  # Wait long enough for metadata refresh and potential consumption to happen
  # With topic.metadata.refresh.interval.ms = 2_000, 15 seconds gives plenty of cycles
  sleep(15)
end

# No messages should have been consumed because the regex "^<topic>" does not match
# "<topic>-1" or "<topic>-2" under the consumer protocol's RE2/J engine
assert !DT.key?(TOPIC1), "Should not have consumed from #{TOPIC1}"
assert !DT.key?(TOPIC2), "Should not have consumed from #{TOPIC2}"
