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

# When we define a pattern that gets assigned a matcher topic and this matcher topic is not part of
# the topics we want to include (by assigned name), we should not include it.

setup_karafka

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .include(:topics, 'x')

draw_routes(create_topics: false) do
  pattern(/.*/) do
    consumer Class.new
  end
end

guarded = []

begin
  start_karafka_and_wait_until do
    true
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
