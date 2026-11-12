# frozen_string_literal: true

# When Karafka quiets while many messages are prefetched and drained, it should finish the work in
# progress and process nothing more. Nothing past the last processed message should be committed and
# a consumer of the same consumer group started after the stop should continue from the next
# message, with no gap.
#
# Small partition fetches and slow batches make librdkafka queue the messages before we poll again.

MESSAGES = 2_000

setup_karafka do |config|
  config.max_messages = 50
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

Karafka::App.monitor.subscribe("app.quiet") do
  DT[:quiet_at] = DT[:offsets].size
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.5)

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

Thread.new do
  sleep(0.1) until DT[:offsets].size >= 300

  Process.kill("TSTP", Process.pid)
end

start_karafka_and_wait_until do
  next false unless DT.key?(:quiet_at)

  # Nothing should be processed after the quiet state is reached
  sleep(2)

  true
end

last = DT[:offsets].last

assert last < MESSAGES - 1
assert_equal DT[:quiet_at], DT[:offsets].size
assert_equal (0..last).to_a, DT[:offsets]

cg = Karafka::App.routes.first.id
committed = Karafka::Admin.read_lags_with_offsets({ cg => [DT.topic] })[cg][DT.topic][0][:offset]

assert_equal last + 1, committed

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

first = nil
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60

while first.nil? && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
  first = consumer.poll(500)
end

consumer.close

assert_equal last + 1, first.offset
