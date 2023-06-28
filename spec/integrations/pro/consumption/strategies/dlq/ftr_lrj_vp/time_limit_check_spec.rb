# frozen_string_literal: true

# Karafka should throttle and wait and should not consume more in a given time window despite data
# being available

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    # just a check that we have this api method included in the strategy
    collapsed?

    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    long_running_job true
    throttling(
      limit: 2,
      interval: 60_000
    )
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

# Since it runs with VPs, we need to sort to make sure it matches as the messages can
# be distributed into independent VPs and run not in dispatch order
assert_equal elements[0..1].sort, DT[0].sort
