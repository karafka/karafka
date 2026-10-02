# frozen_string_literal: true

# When defining in Karafka settings for the producer, consumer groups and share groups (KIP-932)
# in one kafka scope, there should be no warnings raised by librdkafka for the share consumer, as
# no producer or consumer-group only settings should go to it.

require "stringio"

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

setup_karafka do |config|
  config.logger = Logger.new(strio)
  config.logger.level = :debug
  # Producer specific
  config.kafka[:"retry.backoff.ms"] = 10_000
  config.kafka[:"linger.ms"] = 5
  # Consumer group specific
  config.kafka[:"auto.offset.reset"] = "latest"
  config.kafka[:"enable.partition.eof"] = false
  config.kafka[:"max.poll.interval.ms"] = 15_000
  # Consumer common
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }

    DT[:done] << true
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

Karafka.producer.config.logger.level = :debug

Karafka.producer.produce_sync(topic: DT.topic, payload: "test")

start_karafka_and_wait_until do
  !DT[:done].empty?
end

$stdout = proper_stdout
$stderr = proper_stderr

content = strio.string

%w[
  retry.backoff.ms
  linger.ms
  auto.offset.reset
  enable.partition.eof
  max.poll.interval.ms
  partition.assignment.strategy
  heartbeat.interval.ms
  session.timeout.ms
].each do |property|
  assert_equal false, content.include?("Configuration property #{property}"), content
end
