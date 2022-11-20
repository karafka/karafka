# frozen_string_literal: true

# Karafka should run the same strategy for AJ DLQ LRJ MOM as for DLQ LRJ MOM.
#
# Karafka should NOT dispatch the message to the DLQ topic because it's set to false.

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.license.token = pro_license_token
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[1] << true
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    sleep(value.to_f / 20)
    raise StandardError
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      dead_letter_queue topic: false, max_retries: 4
      long_running_job true
      # mom is enabled automatically
    end

    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert DT[0].size >= 10
assert DT[:errors].count >= 10
assert DT[1].empty?
