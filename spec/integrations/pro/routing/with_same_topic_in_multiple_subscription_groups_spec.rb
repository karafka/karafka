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

# Karafka should allow for same topic to be present in multiple subscription groups in the same
# consumer group as long as subscription groups have different names and same consumer class

setup_karafka do |config|
  config.strict_topics_namespacing = false
end

failed = false
consumer_class = Class.new

begin
  draw_routes(create_topics: false) do
    subscription_group :a do
      topic "namespace_collision" do
        consumer consumer_class
      end
    end

    subscription_group :b do
      topic "namespace_collision" do
        consumer consumer_class
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
