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

# When having the DLQ defined, we should be able to manually dispatch things to the DLQ and
# continue processing whenever we want.

# We can use this API to manually move stuff to DLQ without raising any errors upon detecting a
# corrupted message.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      dispatch_to_dlq(message) if message.offset.zero?
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1_000)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:broken)
end

assert_equal DT[:broken].size, 1, DT.data

broken = DT[:broken].first

assert_equal elements[0], broken.raw_payload, DT.data
assert_equal broken.headers["source_topic"], DT.topic
assert_equal broken.headers["source_partition"], "0"
assert_equal broken.headers["source_offset"], "0"
assert_equal broken.headers["source_consumer_group"], Karafka::App.consumer_groups.first.id
