# frozen_string_literal: true

# When we fork a process and use an idempotent producer with reload settings,
# the producer should properly reinitialize in the forked child and be able to
# produce messages.
#
# @see https://github.com/karafka/karafka/issues/3054
# Reproduction for: after fork, idempotent producer fails to reinitialize

setup_karafka do |config|
  config.swarm.nodes = 1
end

PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.logger = Karafka::App.config.logger
  producer_config.max_wait_timeout = 120_000
  producer_config.kafka[:"enable.idempotence"] = true
  producer_config.reload_on_idempotent_fatal_error = true
  producer_config.wait_backoff_on_idempotent_fatal_error = 500
  producer_config.max_attempts_on_idempotent_fatal_error = 5
end

Karafka::App.config.producer = PRODUCER

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    # Verify we can produce from the forked process with the idempotent producer
    producer.produce_sync(topic: DT.topic, payload: "from_fork")

    WRITER.puts(
      [
        Karafka.producer.config.reload_on_idempotent_fatal_error.to_s,
        Karafka.producer.config.max_attempts_on_idempotent_fatal_error.to_s,
        Karafka.producer.config.wait_backoff_on_idempotent_fatal_error.to_s,
        Karafka.producer.idempotent?.to_s,
        "produced"
      ].join("/")
    )
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  result = READER.gets

  next false unless result

  parts = result.strip.split("/")

  DT[:reload_on_idempotent_fatal_error] = parts[0]
  DT[:max_attempts_on_idempotent_fatal_error] = parts[1]
  DT[:wait_backoff_on_idempotent_fatal_error] = parts[2]
  DT[:idempotent] = parts[3]
  DT[:status] = parts[4]

  true
end

# Verify idempotent settings were properly inherited in the fork
assert_equal "true", DT[:reload_on_idempotent_fatal_error]
assert_equal "5", DT[:max_attempts_on_idempotent_fatal_error]
assert_equal "500", DT[:wait_backoff_on_idempotent_fatal_error]
assert_equal "true", DT[:idempotent]
assert_equal "produced", DT[:status]
