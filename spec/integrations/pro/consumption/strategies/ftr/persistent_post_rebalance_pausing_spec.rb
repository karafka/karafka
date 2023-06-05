# frozen_string_literal: true

# When using the filtering API, we can use a persistent storage to transfer the pause over the
# rebalance to the same or other processes.
#
# Here we do not use cooperative.sticky to trigger a revocation during a pause and we continue
# the pause until its end after getting the assignment back.

# Fake DB layer
#
# We do not have to care about topics and partitions because for spec like this we use one
# partition

class DbPause
  class << self
    def pause(offset, time)
      DT[:pause] << [offset, time]
    end

    def fetch
      DT.key?(:pause) ? DT[:pause].last : false
    end
  end
end

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:times] << Time.now.to_f
    DT[:firsts] << messages.first.offset

    persistent_pause(
      messages.first.offset,
      10_000
    )
  end

  def persistent_pause(offset, pause_ms)
    DbPause.pause(offset, Time.now + pause_ms / 1_000)
    pause(offset, pause_ms)
  end
end

class PauseManager
  def initialize(topic, partition)
    @topics = topic
    @partition = partition
  end

  def apply!(messages)
    messages.clear if timeout.positive?
  end

  def applied?
    true
  end

  def action
    timeout.positive? ? :pause : :skip
  end

  def cursor
    ::Karafka::Messages::Seek.new(
      @topic,
      @partition,
      DbPause.fetch.first
    )
  end

  def timeout
    return 0 unless DbPause.fetch

    timeout = DbPause.fetch.last - Time.now
    timeout.negative? ? 0 : timeout * 1_000
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(topic, partition) { PauseManager.new(topic, partition) }
  end
end

consumer = setup_rdkafka_consumer

# Trigger rebalance
other =  Thread.new do
  sleep(0.1) until DT.key?(:times)

  consumer.subscribe(DT.topic)
  consumer.each { break }

  consumer.close
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))
  sleep(0.5)

  DT[:times].count >= 2
end

other.join

assert_equal 2, DT[:times].count
assert(DT[:times].last - DT[:times].first >= 10)
assert_equal [0], DT[:firsts].uniq
