# frozen_string_literal: true

# When creating a producer in forks, forks should inherit all producer settings and not only the
# once coming from th kafka scope
# The id should NOT be inherited not to create confusion.

setup_karafka

# We do it that way because `#setup_karafka` overwrites the producer
PRODUCER = ::WaterDrop::Producer.new do |p_config|
  p_config.kafka = ::Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  p_config.logger = Karafka::App.config.logger
  p_config.max_payload_size = 10_999
end

Karafka::App.config.producer = PRODUCER

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts(
      [
        Karafka.producer.config.max_payload_size.to_s,
        Karafka.producer.id
      ].join('/')
    )
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  max_payload_size, producer_id = READER.gets.strip.split('/')

  DT[:max_payload_size] = max_payload_size
  DT[:producer_id] = producer_id
end

assert_equal DT[:max_payload_size], '10999'
assert PRODUCER.id != DT[:producer_id]
