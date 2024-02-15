# frozen_string_literal: true

# When running LRJ jobs upon shutdown, those jobs will keep running until finished or until reached
# max wait time. During this time, the rebalance changes should propagate and we should be able
# to make decisions also based on the revocation status.

setup_karafka do |config|
  config.concurrency = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if done?

    DT[:started] << true

    # We use loop so in case this would not work, it will timeout and raise an error
    loop do
      # In case we were given back some of the partitions after rebalance, this could get into
      # an infinite loop, hence we need to check it
      return if done? && signaled?

      sleep(0.1)

      next unless revoked?

      DT[:revoked] << partition

      break
    end
  end

  private

  def signaled?
    DT[:revoked].include?(partition)
  end

  def done?
    Karafka::App.stopping? && DT[:started].size >= 10
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 10)
    consumer Consumer
    long_running_job true
  end
end

10.times do |i|
  produce(DT.topic, (i + 1).to_s, partition: i)
end

consumer = setup_rdkafka_consumer

start_karafka_and_wait_until do
  if DT[:started].size >= 10
    # Trigger a rebalance here, it should revoke all partitions
    consumer.subscribe(DT.topic)
    consumer.each { break }

    true
  else
    false
  end
end

consumer.close

assert_equal 10, DT[:revoked].size, DT.data
