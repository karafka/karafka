# frozen_string_literal: true

# Karafka should be able to handle retry_on with immediate retries in OSS as long as there is no
# jitter

setup_karafka(allow_errors: true)
setup_active_job

draw_routes do
  active_job_topic DT.topic
end

class RetryableJob < ActiveJob::Base
  queue_as DT.topic

  retry_on StandardError, attempts: 3, wait: 0, jitter: false

  def perform(job_id)
    # Track execution attempts
    DT[:executions] ||= {}
    DT[:executions][job_id] ||= 0
    DT[:executions][job_id] += 1

    current_attempt = DT[:executions][job_id]

    if current_attempt < 3
      DT[:attempts] ||= []
      DT[:attempts] << "job#{job_id}_attempt_#{current_attempt}"
      raise StandardError, "Simulated failure on attempt #{current_attempt}"
    else
      DT[:success] ||= []
      DT[:success] << "job#{job_id}_success"
    end
  end
end

class FailingJob < ActiveJob::Base
  queue_as DT.topic

  retry_on StandardError, attempts: 3, wait: 0, jitter: false

  def perform(job_id)
    DT[:failed_executions] ||= {}
    DT[:failed_executions][job_id] ||= 0
    DT[:failed_executions][job_id] += 1
    DT[:failed_attempts] ||= []
    DT[:failed_attempts] << "failing_job#{job_id}_attempt_#{DT[:failed_executions][job_id]}"

    raise StandardError, 'Always fails'
  end
end

# Enqueue jobs
RetryableJob.perform_later(1)
RetryableJob.perform_later(2)
FailingJob.perform_later(3)

start_karafka_and_wait_until do
  success_count = DT[:success].size
  failed_count = DT[:failed_attempts].size

  success_count == 2 && failed_count == 3
end

assert_equal 3, DT[:executions][1], 'Job 1 should have been executed 3 times'
assert_equal 3, DT[:executions][2], 'Job 2 should have been executed 3 times'
assert_equal 3, DT[:failed_executions][3], 'Failing job should have been executed 3 times'

expected_attempts = %w[job1_attempt_1 job1_attempt_2 job2_attempt_1 job2_attempt_2]

assert_equal expected_attempts.sort, DT[:attempts].sort

expected_success = %w[job1_success job2_success]
assert_equal expected_success.sort, DT[:success].sort

expected_failed_attempts = %w[failing_job3_attempt_1 failing_job3_attempt_2 failing_job3_attempt_3]

assert_equal expected_failed_attempts, DT[:failed_attempts]
