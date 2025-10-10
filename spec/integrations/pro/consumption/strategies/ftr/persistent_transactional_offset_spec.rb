# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using the Filtering API, we can use persistent storage to transfer last offset that we
# successfully operated on in case of rebalances, even if different process receives the partition
# on a rebalance.

# This allows us to ensure, that things are processed exactly once and in transactions.
#
# Note, though that this requires to have SQL timeouts, etc tuned well.

# Simulates a persistent DB backed offset that can be fetched in any process
#
#
# Keep in mind, this example is a simplification because it forces `#seek` for each assignment
# just to simplify the code.

class DbOffsets
  class << self
    # Fake transaction just for readability of the code
    def transaction
      yield
    end

    def mark_as_consumed(message)
      DT[:offsets] << (message.offset + 1)
    end

    def fetch
      DT[:offsets].last || -1
    end
  end
end

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  # We can use short time to force rebalance
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.kafka[:'auto.commit.interval.ms'] = 500
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DbOffsets.transaction do
        # any operations on message we would want should go here in a transaction...
        DbOffsets.mark_as_consumed(message)
      end

      # Simulate a hang/exit where the assignment is lost
      if message.offset == 5 && !DT.key?(:hanged)
        DT[:hanged] = true
        sleep(11)
      end

      return unless mark_as_consumed!(message)
    end
  end
end

class OffsetManager < Karafka::Pro::Processing::Filters::Base
  def initialize(topic, partition)
    super()
    @topic = topic
    @partition = partition
    @executed = false
    @reset = false
  end

  def apply!(messages)
    if @executed
      @reset = false
      return
    end

    # Care only on first run
    @executed = true
    @reset = true

    @start_offset = [DbOffsets.fetch, messages.first.offset].max

    messages.clear
  end

  def applied?
    true
  end

  def timeout
    0
  end

  def action
    @reset ? :seek : :skip
  end

  def cursor
    ::Karafka::Messages::Seek.new(
      @topic,
      @partition,
      @start_offset
    )
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    filter ->(topic, partition) { OffsetManager.new(topic, partition) }
  end
end

produce_many(DT.topic, DT.uuids(20))

other = Thread.new do
  sleep(0.1) until DT.key?(:hanged)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)
  consumer.each { break }
  consumer.close
end

start_karafka_and_wait_until do
  DT[:offsets].size >= 20
end

other.join

# There should be no duplicates
assert_equal DT[:offsets], (1..20).to_a
