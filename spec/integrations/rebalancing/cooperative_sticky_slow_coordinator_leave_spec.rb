# frozen_string_literal: true

# Karafka should leave a cooperative-sticky consumer group on shutdown even when the revoke-time
# offset commit is still in flight after the assignment is gone (slow coordinator path).
#
# Karafka talks to the broker through a proxy on the `DELAYED` listener that delays each request
# by 150 ms. When the client closes before that commit returns, librdkafka never sends the
# `LeaveGroup`, and the other member gets the partitions only after `session.timeout.ms`.

require "socket"

SESSION_TIMEOUT_MS = 30_000

# Forwards traffic to the broker `DELAYED` listener, delaying client-to-broker bytes
class DelayingProxy
  # @param port [Integer] port to listen on (the `DELAYED` advertised port)
  # @param target_port [Integer] broker port of the `DELAYED` listener
  # @param delay [Float] seconds by which each client-to-broker chunk is delayed
  def initialize(port, target_port, delay)
    @server = TCPServer.new("127.0.0.1", port)
    @target_port = target_port
    @delay = delay

    Thread.new do
      loop { forward(@server.accept) }
    rescue IOError
      nil
    end
  end

  private

  # @param client [TCPSocket]
  def forward(client)
    upstream = TCPSocket.new("127.0.0.1", @target_port)
    chunks = Queue.new

    Thread.new do
      loop { chunks << [now + @delay, client.readpartial(65_536)] }
    rescue IOError, SystemCallError
      chunks.close
    end

    Thread.new do
      while (chunk = chunks.pop)
        wait = chunk.first - now
        sleep(wait) if wait.positive?
        upstream.write(chunk.last)
      end
    rescue IOError, SystemCallError
      nil
    ensure
      upstream.close
    end

    Thread.new do
      IO.copy_stream(upstream, client)
    rescue IOError, SystemCallError
      nil
    ensure
      client.close
    end
  end

  # @return [Float]
  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

DelayingProxy.new(9097, 9096, 0.15)

setup_karafka do |config|
  config.kafka[:"bootstrap.servers"] = "127.0.0.1:9097"
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
  config.kafka[:"session.timeout.ms"] = SESSION_TIMEOUT_MS
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

# Keeps fresh offsets stored, so there is a revoke-time commit to wait for
producer = WaterDrop::Producer.new do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
end

feeder = Thread.new do
  until DT.key?(:stopped_at)
    2.times { |partition| producer.produce_async(topic: DT.topic, payload: "1", partition: partition) }
    sleep(0.01)
  end
end

other = Thread.new do
  sleep(0.1) until DT.key?(:consumed)

  consumer = setup_rdkafka_consumer(
    "partition.assignment.strategy": "cooperative-sticky",
    "session.timeout.ms": SESSION_TIMEOUT_MS
  )
  consumer.subscribe(DT.topic)

  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60

  until Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    consumer.poll(100)

    assigned = consumer.assignment.to_h.fetch(DT.topic, []).size

    DT[:shared] = true if assigned == 1

    if assigned == 2 && DT.key?(:stopped_at)
      DT[:takeover] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - DT[:stopped_at]
      break
    end
  end

  consumer.close
end

start_karafka_and_wait_until do
  DT.key?(:shared)
end

DT[:stopped_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)

other.join
feeder.join
producer.close

assert DT.key?(:takeover)
assert DT[:takeover] < SESSION_TIMEOUT_MS / 2_000.0
