# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to just process all the jobs
# Throttling should slow things down

setup_active_job

setup_karafka(allow_errors: true)

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
  end
end

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    throttling(limit: 10, interval: 2_000)
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

100.times { |value| Job.perform_later(value) }

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[0].size >= 30
end

assert Time.now.to_f - started_at > 2

assert_equal DT[0].sort, (0..29).to_a

# Make sure, we've marked as processed after last VP batch

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

consumer.each do |message|
  assert message.offset >= 30, [DT, message.offset]
  break
end

consumer.close
