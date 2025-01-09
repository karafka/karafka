# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# AJ is only partially mom, because we actually mark AJ jobs as consumed after each. For this
# strategy it means, that applicability of DLQ will be regular after the VP collapse.

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.headers['original_offset'].to_i
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    raise StandardError
  end
end

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    # mom is enabled automatically
    throttling(limit: 5, interval: 1_000)
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 24 && DT[1].size >= 5
end

assert_equal DT[1][0..4], [0, 1, 2, 3, 4]
