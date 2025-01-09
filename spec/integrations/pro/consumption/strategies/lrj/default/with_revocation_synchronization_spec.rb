# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When LRJ job uses a critical section, the revocation job should wait and not be able to
# run its critical section alongside.

setup_karafka do |config|
  config.concurrency = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    synchronize do
      DT[:started] = Time.now.to_f
      sleep(15)
      DT[:stopped] = Time.now.to_f
    end
  end

  def revoked
    DT[:before_revoked] = Time.now.to_f

    synchronize do
      DT[:revoked] = Time.now.to_f
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  if DT.key?(:started)
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    consumer.poll(1_000)
    consumer.close

    sleep(1)

    true
  else
    false
  end
end

lock_range = (DT[:started]..DT[:stopped])

# Make sure that synchronization block works as expected
assert lock_range.include?(DT[:before_revoked])
assert !lock_range.include?(DT[:revoked])
assert DT[:revoked] > DT[:stopped]
