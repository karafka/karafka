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

# We should be able to use error tracker topic understanding to route errors from the same topic
# to two topics based on the consumer group

setup_karafka(allow_errors: %w[consumer.consume.error])

DT[:dlq_topics] = Set.new

class DqlErrorStrategy
  def call(errors_tracker, _attempt)
    case errors_tracker.topic.consumer_group.name
    when DT.consumer_groups[0]
      [:dispatch, DT.topics[1]]
    when DT.consumer_groups[1]
      [:dispatch, DT.topics[2]]
    else
      exit 1
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class ErrorsConsumer < Karafka::BaseConsumer
  def consume
    DT[:dlq_topics] << topic.name
  end
end

draw_routes do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer

      dead_letter_queue(
        topic: :strategy,
        strategy: DqlErrorStrategy.new
      )
    end
  end

  consumer_group DT.consumer_groups[1] do
    topic DT.topics[0] do
      consumer Consumer

      dead_letter_queue(
        topic: :strategy,
        strategy: DqlErrorStrategy.new
      )
    end
  end

  topic DT.topics[1] do
    consumer ErrorsConsumer
  end

  topic DT.topics[2] do
    consumer ErrorsConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(1))

start_karafka_and_wait_until do
  DT[:dlq_topics].size >= 2
end

assert_equal [DT.topics[1], DT.topics[2]].sort, DT[:dlq_topics].sort
