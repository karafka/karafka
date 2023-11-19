# frozen_string_literal: true

# When given partition is revoked for LRJ, we should still have its last available statistics
# In Pro despite extra option, should behave same as in OSS when no forced required

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Make sure we have insights at all
    return pause(messages.first.offset, 1_000) unless insights?

    DT[:running] << true
    DT[0] << insights?
    sleep(5)
    DT[0] << insights?
  end

  def revoked
    DT[:revoked] = true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
    long_running_job(true)
  end
end

produce_many(DT.topic, DT.uuids(1), partition: 0)
produce_many(DT.topic, DT.uuids(1), partition: 1)

consumer = setup_rdkafka_consumer

Thread.new do
  sleep(0.1) until DT[:running].size >= 2

  consumer.subscribe(DT.topic)
  consumer.poll(1_000)
end

start_karafka_and_wait_until do
  DT[0].size >= 4 && DT.key?(:revoked)
end

assert DT[0].all?

consumer.close
