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

# Karafka should fail when we define nodes that cannot be reached

setup_karafka do |config|
  config.swarm.nodes = 3
end

guarded = []

begin
  draw_routes(create_topics: false) do
    consumer_group 'regular' do
      topic 't1' do
        swarm(nodes: (100..200))
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

Karafka::App.routes.clear

begin
  draw_routes(create_topics: false) do
    consumer_group 't2' do
      topic 'regular' do
        swarm(nodes: [100, 123])
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

Karafka::App.routes.clear

begin
  draw_routes(create_topics: false) do
    consumer_group 't2' do
      topic 'regular' do
        swarm(nodes: [2])
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

assert_equal 2, guarded.size
