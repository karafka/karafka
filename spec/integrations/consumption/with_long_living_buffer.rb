# frozen_string_literal: true

# Karafka should allow to create a long living buffer that we can use and fill as we go, beyond
# a single batch of data

# This will force several batches, so we won't end up with 1 huge as this is not what we want here
setup_karafka { |config| config.max_messages = 2 }

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
      DT[0] << true
    end

    @buffer << messages.raw_payloads
  end

  # Transfer the buffer data outside of the consumer
  def shutdown
    DT[:batches] = @batches
    DT[:buffer] = @buffer
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert DT[:batches] >= 50
assert_equal elements, DT[:buffer].flatten
assert(DT[:buffer].all? { |sub| sub.size < 3 })
