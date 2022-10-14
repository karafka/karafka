# frozen_string_literal: true

# When processing beyond the poll interval, we should be kicked out and we should loose the
# assigned partition.
#
# The revocation job should kick in with a proper revoked state.

setup_karafka(
  # Allow max poll interval error as it is expected to be reported in this spec
  allow_errors: %w[connection.client.poll.error]
) do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume_object_ids] << object_id

    sleep(15)

    DT[:markings] << mark_as_consumed!(messages.last)
    DT[:revocations] << revoked?

    DT[:done] << true
  end

  def revoked
    DT[:revoked_object_ids] << object_id
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:done].size >= 2
end

assert (2..3).cover?(DT[:consume_object_ids].size)
assert (2..3).cover?(DT[:consume_object_ids].uniq.size)
assert_equal 2, DT[:revoked_object_ids].size
assert_equal 2, DT[:revoked_object_ids].uniq.size
assert_equal [false], DT[:markings].uniq
assert_equal [true], DT[:revocations].uniq
