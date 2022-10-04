# frozen_string_literal: true

# When processing beyond the poll interval, with fast offset commit, we should pick up from where
# we left without duplicates

setup_karafka(
  # Allow max poll interval error as it is expected to be reported in this spec
  allow_errors: %w[connection.client.poll.error]
) do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.kafka[:'auto.commit.interval.ms'] = 1_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:done] << message.offset

      mark_as_consumed message
    end

    sleep(15)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:done].size >= 2
end

assert DT[:done].uniq.size > 1
assert_equal 1, DT[:done].group_by(&:itself).values.map(&:count).max
