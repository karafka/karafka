# frozen_string_literal: true

# Karafka should allow to run long AJ jobs with MOM, VPs and LRJ because we collapse upon errors.

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

SAMPLES = (0..1_000).to_a.map(&:to_s)

setup_active_job

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
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
    # Make the 0 value last longer for consistency of this spec
    sleep(15) if value.zero? && !DT[0].include?(0)
    DT[0] << value
    raise StandardError
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      dead_letter_queue topic: DT.topics[1], max_retries: 4
      # mom is enabled automatically
      virtual_partitions(
        partitioner: ->(_) { SAMPLES.pop }
      )
      long_running_job true
    end

    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10 && DT[1].size >= 5
end

assert_equal (0..4).to_a, DT[1], DT[1]

first_zero = DT[0].index(0)

# We should skip and continue processing with each job after 4 retries
DT[0][first_zero..24].each_slice(5).with_index do |slice, index|
  assert_equal 1, slice.uniq.size, DT[0]
  assert_equal index, slice.first, DT[0]
end
