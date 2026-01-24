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

# Validations should work as expected and routing definitions should be ok

setup_karafka

guarded = false

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_group do
      # Disabled ok
      parallel_segments(count: 1)

      topic DT.topic do
        consumer Karafka::BaseConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded = true
end

assert !Karafka::App.routes.first.parallel_segments.active?
assert !guarded

Karafka::App.routes.clear
guarded = false

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_group do
      # Too few
      parallel_segments(count: 0)

      topic DT.topic do
        consumer Karafka::BaseConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded = true
end

assert guarded

Karafka::App.routes.clear
guarded = false

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_group do
      # Enough but no partitioner
      parallel_segments(count: 2)

      topic DT.topic do
        consumer Karafka::BaseConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded = true
end

assert guarded

Karafka::App.routes.clear
guarded = false

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_group do
      # Enough with partitioner
      parallel_segments(
        count: 2,
        partitioner: ->(message) { message.key }
      )

      topic DT.topic do
        consumer Karafka::BaseConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded = true
end

assert !guarded

assert Karafka::App.routes.first.parallel_segments.active?
assert_equal 2, Karafka::App.routes.size
assert_equal "#{DT.consumer_group}-parallel-0", Karafka::App.routes.first.name
assert_equal "#{DT.consumer_group}-parallel-1", Karafka::App.routes.last.name
