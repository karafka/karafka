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

# I should be able to define a topic consumption with virtual partitioner.
# It should not impact other jobs and the default should not have it.

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Class.new(Karafka::BaseConsumer)
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end

  topic DT.topics[1] do
    consumer Class.new(Karafka::BaseConsumer)
  end

  topic DT.topics[2] do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

assert Karafka::App.routes.first.topics[0].virtual_partitions?
assert_equal false, Karafka::App.routes.first.topics[1].virtual_partitions?
assert_equal false, Karafka::App.routes.first.topics[2].virtual_partitions?
