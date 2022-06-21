# frozen_string_literal: true

# When processing beyond the poll interval, we should be kicked out and we should loose the
# assigned partition.
#
# The revocation job should kick in with a proper revoked state.

setup_karafka do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[:consume_object_ids] << object_id

    sleep(15)

    DataCollector.data[:markings] << mark_as_consumed!(messages.last)
    DataCollector.data[:revocations] << revoked?

    DataCollector[:done] << true
  end

  def revoked
    DataCollector.data[:revoked_object_ids] << object_id
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector[:done].size >= 2
end

assert_equal 2, DataCollector.data[:consume_object_ids].size
assert_equal 2, DataCollector.data[:consume_object_ids].uniq.size
assert_equal 2, DataCollector.data[:revoked_object_ids].size
assert_equal 2, DataCollector.data[:revoked_object_ids].uniq.size
assert_equal [false, false], DataCollector.data[:markings]
assert_equal [true, true], DataCollector.data[:revocations]
