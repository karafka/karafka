# frozen_string_literal: true

# Repeatedly creating and closing rdkafka consumers (the way Karafka does during multiplexing
# scale-up / scale-down) must not leak pipe file descriptors. Each consumer cycle creates a new
# librdkafka client with internal pipes; rd_kafka_destroy must clean them all up.
#
# We also cycle a WaterDrop producer alongside each consumer to exercise the producer pipe
# (QueuePipe) lifecycle, since a real swarm node has both consumers and producers active.

LINUX = RUBY_PLATFORM.include?("linux")

setup_karafka do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

def count_pipe_fds
  Dir.glob("/proc/self/fd/*").count do |fd_path|
    File.readlink(fd_path).start_with?("pipe:")
  rescue Errno::ENOENT
    false
  end
end

# Build kafka config exactly the way Karafka::Connection::Client#build_consumer does
def build_kafka_config
  sg = Karafka::App.subscription_groups.values.flatten.first

  config = Rdkafka::Config.new(sg.kafka.merge("group.id": SecureRandom.uuid))
  # Karafka always splits events queue from consumer queue
  config.consumer_poll_set = false
  config
end

# Cycle: create consumer, subscribe, poll briefly, close — mirrors multiplexing scale-up/down
def create_and_destroy_consumer
  config = build_kafka_config
  consumer = config.consumer
  consumer.subscribe(DT.topic)

  # Poll a few times to let librdkafka establish internal threads/pipes
  3.times do
    consumer.poll(100)
    consumer.events_poll(50)
  end

  consumer.close
end

# Also cycle a WaterDrop producer alongside to exercise producer QueuePipe lifecycle
def create_and_destroy_producer
  kafka_config = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)

  producer = WaterDrop::Producer.new do |p_config|
    p_config.kafka = kafka_config
    p_config.logger = Karafka::App.config.logger
  end

  producer.produce_sync(topic: DT.topic, payload: "test")
  producer.close
end

pipe_counts = []

# Warm up — let the first consumer/producer creation settle
create_and_destroy_consumer
create_and_destroy_producer

# Wait for background librdkafka threads to fully shut down
sleep(1)

pipe_counts << count_pipe_fds if LINUX

# Run 20 create/destroy cycles to expose any per-cycle FD leak
20.times do |i|
  create_and_destroy_consumer
  create_and_destroy_producer

  # Let librdkafka fully clean up between cycles
  sleep(0.5) if (i % 5).zero?

  pipe_counts << count_pipe_fds if LINUX
end

# Final settle
sleep(1)
pipe_counts << count_pipe_fds if LINUX

if LINUX && pipe_counts.size >= 2
  growth = pipe_counts.last - pipe_counts.first

  # With 20 cycles, if each leaks even 1 pipe we'd see growth of 20+.
  # Allow small tolerance for timing/GC variance.
  assert(
    growth <= 4,
    "Pipe FDs grew by #{growth} over 20 consumer+producer cycles " \
    "(#{pipe_counts.first} -> #{pipe_counts.last}), counts: #{pipe_counts.inspect}"
  )
end
