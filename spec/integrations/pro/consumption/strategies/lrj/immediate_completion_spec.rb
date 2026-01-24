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

# LRJ should handle jobs that complete immediately without any actual long-running work,
# ensuring proper resource management and offset handling.

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 5
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class ImmediateCompletionConsumer < Karafka::BaseConsumer
  def consume
    start_time = Time.now

    messages.each do |message|
      # Try to parse as JSON first, fallback to raw payload
      begin
        data = JSON.parse(message.raw_payload)
        job_type = if data.is_a?(Hash) && data.key?('valid')
                     'validation_only'
                   else
                     message.raw_payload
                   end
      rescue JSON::ParserError
        job_type = message.raw_payload
      end

      case job_type
      when 'instant'
        # Job that completes immediately without any work
        DT[:instant_jobs] << {
          start_time: start_time,
          completion_time: Time.now,
          duration: 0
        }
      when 'validation_only'
        # Job that only does quick validation and returns
        # data is already parsed above
        DT[:validation_jobs] << {
          start_time: start_time,
          completion_time: Time.now,
          valid: data['valid']
        }
      when 'quick_lookup'
        # Job that does a quick lookup and exits
        result = { 'lookup_key' => message.offset }
        DT[:lookup_jobs] << {
          start_time: start_time,
          completion_time: Time.now,
          result: result
        }
      when 'conditional_processing'
        # Job that may exit early based on conditions
        DT[:conditional_jobs] << {
          start_time: start_time,
          completion_time: Time.now,
          processed: message.offset.even?,
          offset: message.offset
        }
      when 'error_check'
        # Job that checks for errors and exits if none found
        DT[:error_check_jobs] << {
          start_time: start_time,
          completion_time: Time.now,
          has_errors: message.offset >= 13
        }
      end
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer ImmediateCompletionConsumer
    deserializer ->(message) { message.raw_payload }
    long_running_job true
  end
end

# Produce different types of immediately-completing jobs
job_types = %w[
  instant
  validation_only
  quick_lookup
  conditional_processing
  error_check
]

# Produce multiple instances of each job type
job_types.each do |job_type|
  3.times do |i|
    payload = case job_type
              when 'validation_only'
                { valid: i.even? }.to_json
              else
                job_type
              end

    produce(DT.topic, payload)
  end
end

start_karafka_and_wait_until do
  total_jobs = DT[:instant_jobs].size +
               DT[:validation_jobs].size +
               DT[:lookup_jobs].size +
               DT[:conditional_jobs].size +
               DT[:error_check_jobs].size

  total_jobs >= 15
end

# Verify instant jobs completed immediately
DT[:instant_jobs].each do |job|
  duration = job[:completion_time] - job[:start_time]
  assert duration < 0.1, "Instant job took too long: #{duration}"
end

# Verify validation jobs handled different scenarios
valid_validations = DT[:validation_jobs].count { |job| job[:valid] }
invalid_validations = DT[:validation_jobs].count { |job| !job[:valid] }
assert valid_validations >= 1
assert invalid_validations >= 1

# Verify lookup jobs completed quickly
DT[:lookup_jobs].each do |job|
  duration = job[:completion_time] - job[:start_time]
  assert duration < 0.1, "Lookup job took too long: #{duration}"
  assert job[:result].is_a?(Hash)
end

# Verify conditional processing worked correctly
processed_jobs = DT[:conditional_jobs].select { |job| job[:processed] }
skipped_jobs = DT[:conditional_jobs].reject { |job| job[:processed] }
assert processed_jobs.size >= 1
assert skipped_jobs.size >= 1

# Verify even offsets were processed, odd were skipped
processed_jobs.each do |job|
  assert job[:offset].even?, "Odd offset should not have been processed: #{job[:offset]}"
end

skipped_jobs.each do |job|
  assert job[:offset].odd?, "Even offset should not have been skipped: #{job[:offset]}"
end

# Verify error check jobs completed immediately regardless of result
DT[:error_check_jobs].each do |job|
  duration = job[:completion_time] - job[:start_time]
  assert duration < 0.1, "Error check job took too long: #{duration}"
end

# Verify both error and non-error cases were handled
jobs_with_errors = DT[:error_check_jobs].count { |job| job[:has_errors] }
jobs_without_errors = DT[:error_check_jobs].count { |job| !job[:has_errors] }
assert jobs_with_errors >= 1
assert jobs_without_errors >= 1
