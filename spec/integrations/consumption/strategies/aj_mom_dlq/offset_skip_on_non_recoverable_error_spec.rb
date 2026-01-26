# frozen_string_literal: true

# When there is ActiveJob processing error that cannot recover, upon moving to DLQ, the offset
# should be moved as well.

setup_karafka(allow_errors: true)
setup_active_job

draw_routes do
  active_job_topic DT.topics[0] do
    dead_letter_queue topic: DT.topics[1], max_retries: 1
  end
end

class Job < ActiveJob::Base
  queue_as DT.topics[0]

  def perform(val)
    DT[0] << val

    raise(StandardError) if val.zero?
  end
end

Job.perform_later(0)

start_karafka_and_wait_until do
  DT[0].size >= 2
end

# We need a new producer just to create a message to this topic to check the start offset
# as after valid consumption there will be only one message
producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka)
end

producer.produce_async(topic: DT.topics[0], payload: "{}")

assert_equal 1, fetch_next_offset

producer.close
