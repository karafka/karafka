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

# Karafka should not build separate SGs when altering pause settings per topic in a SG/CG

setup_karafka

draw_routes(create_topics: false) do
  topic "topic1" do
    consumer Class.new
    pause(
      timeout: 100,
      max_timeout: 1_000,
      with_exponential_backoff: true
    )
  end

  topic "topic2" do
    consumer Class.new
    pause(
      timeout: 200,
      max_timeout: 2_000,
      with_exponential_backoff: false
    )
  end
end

t1 = Karafka::App.consumer_groups.first.topics.first
t2 = Karafka::App.consumer_groups.first.topics.last

assert_equal t1.subscription_group, t2.subscription_group

assert_equal t1.pause_timeout, 100
assert_equal t1.pause_max_timeout, 1_000
assert_equal t1.pause_with_exponential_backoff, true

assert_equal t2.pause_timeout, 200
assert_equal t2.pause_max_timeout, 2_000
assert_equal t2.pause_with_exponential_backoff, false
