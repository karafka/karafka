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

# Karafka should not allow for using VP with DLQ without retries

setup_karafka do |config|
  config.concurrency = 10
end

guarded = []

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_group do
      topic DT.topic do
        consumer Class.new(Karafka::BaseConsumer)
        virtual_partitions(
          partitioner: ->(msg) { msg.raw_payload }
        )
        dead_letter_queue(
          topic: 'test',
          max_retries: 0
        )
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
