# frozen_string_literal: true

# When we exceed max.poll.interval the error should contain CG name

strio = StringIO.new

setup_karafka(
  # Allow max poll interval error as it is expected to be reported in this spec
  allow_errors: %w[connection.client.poll.error]
) do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(15)

    DT[:done] << true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

logs = strio.string

assert logs.include?("Application maximum poll interval (10000ms)")
assert logs.include?("[consumer_group: #{DT.consumer_group}")
