# frozen_string_literal: true

# Share group (KIP-932) processing should use the monitor and logger set during the configuration,
# even when the default ones were already referenced (cached) before the setup.

Karafka.logger
Karafka.monitor

LOG = StringIO.new
POST_LOGGER = Logger.new(LOG)
POST_MONITOR = Karafka::Instrumentation::Monitor.new

setup_karafka do |config|
  config.logger = POST_LOGGER
  config.monitor = POST_MONITOR
end

assert_equal POST_LOGGER, Karafka.logger
assert_equal POST_MONITOR, Karafka.monitor

POST_MONITOR.subscribe("consumer.consumed") do |event|
  DT[:consumed] << event[:caller].class
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
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

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].size >= 5 && !DT[:consumed].empty?
end

assert_equal elements.sort, DT[:accepted].sort
assert_equal [Consumer], DT[:consumed].uniq
# Share group processing is logged via the replaced logger
assert LOG.string.include?(DT.topic)
