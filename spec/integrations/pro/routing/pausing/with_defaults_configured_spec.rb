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

# A topic's own pause should win over a routing defaults pause, while topics without one, including
# the recurring tasks schedules topic, keep using their own or the defaults one

setup_karafka

draw_routes(create_topics: false) do
  defaults do
    pause(timeout: 100, max_timeout: 200)
    pause(with_exponential_backoff: true)
  end

  recurring_tasks(true)

  topic :a do
    consumer Class.new(Karafka::BaseConsumer)
    pause(timeout: 5_000)
    pause(max_timeout: 50_000)
  end

  topic :b do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

topics = Karafka::App.routes.flat_map { |consumer_group| consumer_group.topics.to_a }
schedules = topics.find(&:recurring_tasks?)
topic_a = topics.find { |topic| topic.name == "a" }
topic_b = topics.find { |topic| topic.name == "b" }

assert_equal 60_000, schedules.pause.timeout
assert_equal 60_000, schedules.pause.max_timeout

assert_equal true, topic_a.pause.active?
assert_equal 5_000, topic_a.pause.timeout
assert_equal 50_000, topic_a.pause.max_timeout
assert_equal false, topic_a.pause.with_exponential_backoff

assert_equal true, topic_b.pause.active?
assert_equal 100, topic_b.pause.timeout
assert_equal 200, topic_b.pause.max_timeout
assert_equal true, topic_b.pause.with_exponential_backoff
