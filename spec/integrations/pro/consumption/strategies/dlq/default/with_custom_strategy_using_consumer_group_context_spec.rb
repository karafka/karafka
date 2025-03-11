# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

assert_equal DT[:dlq_topics].sort, [DT.topics[1], DT.topics[2]].sort
