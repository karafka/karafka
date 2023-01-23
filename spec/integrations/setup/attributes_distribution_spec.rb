# frozen_string_literal: true

# When defining in Karafka settings for both producer and consumer, there should be no warnings
# raised by librdkafka as no producer settings should go to consumer and the other way around.

require 'stringio'

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

setup_karafka do |config|
  config.logger = Logger.new(strio)
  config.logger.level = :debug
  # Producer specific
  config.kafka[:'retry.backoff.ms'] = 10_000
  # Consumer specific
  config.kafka[:'max.poll.interval.ms'] = 15_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

Karafka.producer.config.logger.level = :debug

Karafka.producer.produce_sync(topic: DT.topic, payload: 'test')

start_karafka_and_wait_until do
  !DT[:done].empty?
end

$stdout = proper_stdout
$stderr = proper_stderr

content = strio.string

assert_equal false, content.include?('Configuration property heartbeat.interval.ms'), content
assert_equal false, content.include?('Configuration property max.poll.interval.ms'), content
