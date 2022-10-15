# frozen_string_literal: true

# When older message then the one we already marked is marked as processed, this should be ignored.
# We should only mark stuff moving forward.
#
# This aligns with librdkafka behaviour for offsets (see note):
# https://github.com/edenhill/librdkafka/blob/master/INTRODUCTION.md#at-least-once-processing

setup_karafka(
  # Allow max poll interval error as it is expected to be reported in this spec
  allow_errors: %w[connection.client.poll.error]
) do |config|
  config.max_messages = 20
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    track

    return if messages.size < 2

    mark

    return unless DT[:first_one].empty?

    # We force a rebalance by reaching the max poll interval
    DT[:first_one] << true
    DT[:expected_next] << messages.last.offset + 1

    sleep(15)
  end

  private

  def track
    messages.each do |message|
      DT[:offsets] << message.offset
    end
  end

  def mark
    mark_as_consumed! messages.last
    sleep(0.1)
    mark_as_consumed! messages.first
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  next false if DT[:expected_next].empty?

  DT[:offsets].size >= 60
end

assert_equal DT[:offsets].uniq.count, DT[:offsets].count
