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

# When using a complex dispatch strategy based on error type, it should operate as expected.
# Please keep in mind, this spec does not care about the fact, that during recovery different
# errors occur. It uses notion of last error only.
#
# We should be able to dispatch to customized target topics bypassing the default if needed.

setup_karafka(allow_errors: %w[consumer.consume.error])

# This should be retried always
DbError = Class.new(StandardError)

# This should be always skipped asap
NonRecoverableError = Class.new(StandardError)

# This should be retried 1 time
RecoverableError = Class.new(StandardError)

# A different error with default of 5 attempts
OtherError = Class.new(StandardError)

ERRORS = [
  DbError,
  NonRecoverableError,
  RecoverableError,
  OtherError
].freeze

class DqlErrorStrategy
  def call(errors_tracker, attempt)
    case errors_tracker.last
    # Always retry on any DB related errors
    when DbError
      :retry
    # Never retry on non-recoverable errors
    when NonRecoverableError
      :skip
    # On this specific recoverable retry at most 2 times
    when RecoverableError
      (attempt > 2) ? [:dispatch, DT.topics[2]] : :retry
    else
      # And for any other errors, retry 5 times
      (attempt > 5) ? [:dispatch, DT.topics[3]] : :retry
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    error = errors_tracker.last

    DT[:errors] << [error&.class, attempt]

    raise ERRORS[partition]
  end
end

class ErrorsConsumer < Karafka::BaseConsumer
  def consume
    # This should never happen despite if being default as we redirect errors via custom strategy
    # to a different DLQ topic
    exit 10 if topic.name == DT.topics[1]

    DT[:target_errors2] = true
    DT[:target_errors3] = true
  end
end

draw_routes do
  topic DT.topics[0] do
    config(partitions: ERRORS.size)
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      strategy: DqlErrorStrategy.new
    )
  end

  topic DT.topics[1] do
    consumer ErrorsConsumer
  end

  topic DT.topics[2] do
    consumer ErrorsConsumer
  end

  topic DT.topics[3] do
    consumer ErrorsConsumer
  end
end

start_karafka_and_wait_until do
  4.times do |i|
    produce(DT.topic, "", partition: i)
  end

  sleep(0.1)

  DT[:errors].size >= 50 && DT.key?(:target_errors2) && DT.key?(:target_errors3)
end

# Non recoverable will always skip, so only one attempt
non_recoverable = DT[:errors].select { |error| error.first.nil? }
assert_equal [1], non_recoverable.map(&:last).uniq

# DB error should be retried many times without limit
db = DT[:errors].select { |error| error.first == DbError }
assert db.map(&:last).max >= 6

# Recoverable should give up after 3 attempts as it either recovers or fails (we emulate failure)
recoverable = DT[:errors].select { |error| error.first == RecoverableError }
assert recoverable.map(&:last).max <= 3

# Other errors should have 6 attempts at most
other = DT[:errors].select { |error| error.first == OtherError }
assert other.map(&:last).max <= 6
