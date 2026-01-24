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

# When providing invalid config details for scheduled messages, validation should kick in.

become_pro!

begin
  Karafka::App.setup do |config|
    config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
    config.recurring_tasks.interval = -1
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  guarded = true
  error = e
end

assert guarded

assert_equal(
  error.message,
  { 'config.recurring_tasks.interval': 'needs to be equal or more than 1000 and an integer' }.to_s
)
