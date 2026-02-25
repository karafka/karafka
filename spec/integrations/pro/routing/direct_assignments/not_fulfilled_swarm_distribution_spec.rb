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

# When we decide to assign certain set of partitions and run in swarm, this set of partitions
# should match the nodes mapping

# We also should not be able to allocate partitions that are not assigned

setup_karafka do |config|
  config.swarm.nodes = 3
end

failed = false

begin
  draw_routes(create_topics: false) do
    topic :a do
      consumer Class.new
      # We want to assign 5 partitions but only 3 are in use
      assign(0..5)
      swarm(
        nodes: {
          0 => [0],
          1 => [1],
          2 => [2]
        }
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

Karafka::App.routes.clear

failed = false

begin
  draw_routes(create_topics: false) do
    topic :a do
      consumer Class.new
      # We want to assign 5 partitions but only 3 are in use
      assign(0..3)
      swarm(
        nodes: {
          0 => [0, 1, 2],
          1 => [3],
          2 => [4]
        }
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
