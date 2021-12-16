# frozen_string_literal: true

# Karafka should allow to create a long living buffer that we can use and fill as we go, beyond
# a single batch of data

# This will force several batches, so we won't end up with 1 huge as this is not what we want here
setup_karafka { |config| config.max_messages = 2 }

elements = Array.new(100) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def initialize
    super
    # Karafka never uses same consumer instance for multiple partitions of the same topic, thus we
    # do not need thread safe structures here
    @buffer = []
    @batches = 0
  end

  def consume
    @batches += 1

    messages.each do
      DataCollector.data[0] << true
    end

    @buffer << messages.raw_payloads
  end

  # Transfer the buffer data outside of the consumer
  def on_shutdown
    DataCollector.data[:batches] = @batches
    DataCollector.data[:buffer] = @buffer
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

assert_equal 50, DataCollector.data[:batches]
assert_equal elements, DataCollector.data[:buffer].flatten
assert_equal true, (DataCollector.data[:buffer].all? { |sub| sub.size < 3 })
