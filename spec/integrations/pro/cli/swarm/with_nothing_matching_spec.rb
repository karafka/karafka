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

# Karafka in swarm should raise well nested validated errors with the swarm context

setup_karafka

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      config(partitions: 2)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--topics'
ARGV[2] = 't1,t2'

failed = false

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('swarm.cli.include_topics')
  failed = true
end

assert failed
