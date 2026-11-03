# frozen_string_literal: true

# Swarm nodes are forked after setup started the Ractor pool. Each node should run its own
# workers and use their results instead of hanging on the pool of the supervisor.

exit 0 if RUBY_VERSION < "4.0"

setup_karafka do |config|
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 1
end

READER, WRITER = IO.pipe

class RactorTaggingDeserializer
  def call(_message)
    (Ractor.current == Ractor.main) ? "main" : "ractor"
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| WRITER.puts(message.payload) }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializing(
      payload: RactorTaggingDeserializer.new.freeze,
      parallel: true
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until(mode: :swarm) do
  DT[:sources] << READER.gets.strip
  DT[:sources].size >= 10
end

assert DT[:sources].all?("ractor"), DT[:sources].tally.inspect
