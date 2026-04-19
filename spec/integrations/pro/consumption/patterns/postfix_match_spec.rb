# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka should match over postfix regexp

setup_karafka do |config|
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] = topic
  end
end

draw_routes(create_topics: false) do
  pattern(/.*#{DT.topics[1]}/) do
    consumer Consumer
  end
end

# If works, won't hang.
TOPIC_NAME = "#{DT.topics[0]}-#{DT.topics[1]}"

start_karafka_and_wait_until do
  unless @created
    sleep(5)
    Karafka::Admin.create_topic(TOPIC_NAME, 1, 1)
    produce_many(TOPIC_NAME, DT.uuids(1))
    @created = true
  end

  DT.key?(0)
end

# Make sure that the expansion of routing works and that proper subscription group is assigned
assert_equal 2, Karafka::App.subscription_groups.values.first.first.topics.size
assert_equal DT[0].subscription_group, Karafka::App.subscription_groups.values.first.first
