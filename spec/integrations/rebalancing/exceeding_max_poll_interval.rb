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
    DT.data[:consume_object_ids] << object_id

    sleep(15)

    DT.data[:markings] << mark_as_consumed!(messages.last)
    DT.data[:revocations] << revoked?

    DT[:done] << true
  end

  def revoked
    DT.data[:revoked_object_ids] << object_id
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:done].size >= 2
end

assert_equal 2, DT.data[:consume_object_ids].size
assert_equal 2, DT.data[:consume_object_ids].uniq.size
assert_equal 2, DT.data[:revoked_object_ids].size
assert_equal 2, DT.data[:revoked_object_ids].uniq.size
assert_equal [false, false], DT.data[:markings]
assert_equal [true, true], DT.data[:revocations]
