# frozen_string_literal: true

# When we have an vp and not the first job fails, it should use regular Karafka retry policies
# for parallel jobs. In general it should not mark intermediate jobs as consumed.

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
  config.concurrency = 1
  config.max_messages = 60
  config.max_wait_time = 2_000
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic do
      virtual_partitioner ->(_) { [true, false].sample }
    end
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  def perform(number)
    if number == 95 && !DataCollector[0].include?(number)
      DataCollector[0] << number
      raise StandardError
    end

    DataCollector[0] << number

    sleep 0.1
  end
end

100.times { |i| Job.perform_later(i) }

start_karafka_and_wait_until do
  DataCollector[0].uniq.sort.size >= 100
end

# If we would mark as consumed
assert_equal 2, (DataCollector[0].count { |nr| nr == 94 })
assert_equal DataCollector[0].uniq.sort, (0..99).to_a
