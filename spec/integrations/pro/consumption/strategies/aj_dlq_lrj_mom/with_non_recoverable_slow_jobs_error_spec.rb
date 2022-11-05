# frozen_string_literal: true

exit 8

# Karafka should run the same strategy for AJ DLQ LRJ MOM as for DLQ LRJ MOM
# For AJ based workloads it means marking after each. This means, we will never end up in a loop
# This resembles a non MOM standard flow for LRJ DLQ (management of work is on AJ base).

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

setup_active_job

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.license.token = pro_license_token
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

create_topic(name: DT.topics[0])
create_topic(name: DT.topics[1])

class DlqConsumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << [message.offset]
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

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      dead_letter_queue topic: DT.topics[1]
      long_running_job true
      # mom is enabled automatically
    end

    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

100.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 100 && DT[1].size >= 100
end


p DT.data[0]
p DT.data[1]

exit

100.times do |value|
  assert_equal value, DT[0][value]
end
