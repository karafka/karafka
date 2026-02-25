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

# ActiveJob jobs should be distributed to consumers based on their segment group assignment

setup_karafka
setup_active_job

# Simple job that just records it was executed
class TrackingJob < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    partitioner: ->(job) { job.arguments.first },
    partition_key_type: :key
  )

  def perform(job_id)
    # Record that this job was processed
    DT[:processed_jobs] << job_id
  end
end

DT[:segments] = Set.new

# Separate monitoring consumer that tracks segment information
# This consumer will run in a different consumer group but consume the same topic
class SegmentMonitorConsumer < Karafka::BaseConsumer
  def consume
    # Get the segment ID
    segment_id = topic.consumer_group.segment_id

    # Track segment info for all incoming messages
    messages.each do |message|
      payload = JSON.parse(message.raw_payload)

      arguments = payload["arguments"]
      job_id = arguments.first

      DT[:segments] << segment_id

      # Record the segment that received this message
      DT[:message_segments] << {
        job_id: job_id,
        segment_id: segment_id
      }
    end
  end
end

draw_routes do
  # Main consumer group with parallel segments for ActiveJob processing
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    active_job_topic DT.topic
  end

  # Separate monitoring consumer group with parallel segments
  # This just tracks which segment received which message
  consumer_group "#{DT.consumer_group}-monitor" do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer SegmentMonitorConsumer
    end
  end
end

# Create jobs with deterministic keys that will map to specific segments
segment_jobs = { 0 => [], 1 => [], 2 => [] }

# Create job IDs for each segment
10.times do |i|
  [0, 1, 2].each do |target_segment|
    # Create a job ID that will map to the target segment
    job_id = nil
    (0..100).each do |j|
      candidate = "job-seg#{target_segment}-#{i}-#{j}"
      if candidate.to_s.sum % 3 == target_segment
        job_id = candidate
        break
      end
    end

    segment_jobs[target_segment] << job_id
  end
end

# Track expected segment assignment
DT[:expected_segments] = {}
segment_jobs.each do |segment_id, job_ids|
  job_ids.each do |job_id|
    DT[:expected_segments][job_id] = segment_id
  end
end

# Enqueue all jobs (flattened and shuffled)
all_jobs = segment_jobs.values.flatten
all_jobs.shuffle.each do |job_id|
  TrackingJob.perform_later(job_id)
end

# Start Karafka and wait until enough jobs are processed
start_karafka_and_wait_until do
  DT[:processed_jobs].size >= 20 && DT[:segments].size >= 3
end

# 1. Verify each message was routed to its expected segment
DT[:message_segments].each do |record|
  job_id = record[:job_id]
  actual_segment = record[:segment_id]
  expected_segment = DT[:expected_segments][job_id]

  assert_equal(
    expected_segment,
    actual_segment,
    "Job #{job_id} was processed by segment #{actual_segment} but should be #{expected_segment}"
  )
end

[0, 1, 2].each do |segment_id|
  # 2. Verify each segment processed some jobs
  segment_count = DT[:message_segments].count { |msg| msg[:segment_id] == segment_id }

  assert(
    segment_count > 0,
    "Segment #{segment_id} didn't process any jobs"
  )
  # 3. Verify the distribution is roughly as expected
  expected_count = segment_jobs[segment_id].size
  actual_count = DT[:message_segments].count { |msg| msg[:segment_id] == segment_id }

  # Allow for some jobs that might not have been processed yet
  assert(
    actual_count >= expected_count / 3,
    "Segment #{segment_id} processed too few jobs: #{actual_count} of #{expected_count} expected"
  )
end

# 4. Calculate and display distribution stats
jobs_per_segment = Hash.new(0)
DT[:message_segments].each do |record|
  jobs_per_segment[record[:segment_id]] += 1
end

# 5. Verify all processed jobs came from our test set
processed_job_ids = DT[:processed_jobs]
unknown_job_ids = processed_job_ids - all_jobs

assert_equal(
  [],
  unknown_job_ids,
  "Found jobs with unexpected IDs: #{unknown_job_ids}"
)
