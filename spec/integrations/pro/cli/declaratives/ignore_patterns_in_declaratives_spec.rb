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

# karafka declarative topics management should ignore pattern topics because they are dynamic
# subscriptions for which we do not know the target name until the regexp match
Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    config(
      partitions: 2,
      "cleanup.policy": "compact"
    )

    consumer Consumer
  end

  pattern(/test.*me-karafka-specs/) do
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "create"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

names = Karafka::App.routes.flat_map(&:topics).flat_map(&:to_a).map(&:name)

assert cluster_topics.include?(names[0])
assert cluster_topics.include?(names[1])
# Regexp names should not be used in declaratives
assert !cluster_topics.include?(names[2])
