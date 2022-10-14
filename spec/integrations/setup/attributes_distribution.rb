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
  config.kafka[:'retry.backoff.ms'] = 1_000
  # Consumer specific
  config.kafka[:'max.poll.interval.ms'] = 1_000
end

Karafka.producer.config.logger.level = :debug

Karafka.producer.produce_sync(topic: DT.topic, payload: 'test')

start_karafka_and_wait_until do
  true
end

$stdout = proper_stdout
$stderr = proper_stderr

assert_equal false, strio.string.include?('Configuration property heartbeat.interval.ms')
assert_equal false, strio.string.include?('Configuration property max.poll.interval.ms')
