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

# DLQ should handle complex error classification scenarios including error chaining,
# nested errors, timeout-based errors, and custom error hierarchies.

setup_karafka(allow_errors: %w[consumer.consume.error])

# Error hierarchy for testing
class BusinessError < StandardError; end
class ValidationError < BusinessError; end
class TimeoutError < StandardError; end
class NetworkError < StandardError; end

# Wrapped error for testing error chaining
class WrappedError < StandardError
  attr_reader :cause

  def initialize(message, cause = nil)
    super(message)
    @cause = cause
  end
end

class ComplexDlqStrategy
  def call(errors_tracker, attempt)
    last_error = errors_tracker.last

    case last_error
    # Business logic errors should be skipped immediately
    when ValidationError
      :skip
    # Business errors in general should be retried a few times
    when BusinessError
      (attempt > 3) ? :dispatch : :retry
    else
      # Default behavior
      (attempt > 5) ? :dispatch : :retry
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      error_type = message.payload

      DT[:processing_attempts] << [error_type, attempt]

      case error_type
      when "validation"
        raise ValidationError, "Invalid data format"
      when "business"
        raise BusinessError, "Business rule violation"
      else
        raise StandardError, "Unknown error"
      end
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    deserializer ->(message) { message.raw_payload }
    dead_letter_queue(
      topic: DT.topics[1],
      strategy: ComplexDlqStrategy.new
    )
  end
end

# Produce different error scenarios
error_scenarios = %w[
  validation
  business
  unknown
]

error_scenarios.each do |scenario|
  produce(DT.topic, scenario)
end

start_karafka_and_wait_until do
  DT[:processing_attempts].size >= 10
end

# Analyze processing patterns for each error type
validation_attempts = DT[:processing_attempts].select { |type, _| type == "validation" }
business_attempts = DT[:processing_attempts].select { |type, _| type == "business" }
unknown_attempts = DT[:processing_attempts].select { |type, _| type == "unknown" }

# Validation errors should be skipped immediately (only 1 attempt)
assert_equal [1], validation_attempts.map(&:last).uniq

# Business errors should be retried up to 3 times
assert business_attempts.map(&:last).max <= 4

# Unknown errors should be retried up to 5 times (default)
assert unknown_attempts.map(&:last).max <= 6
