# frozen_string_literal: true

# Karafka should leave a cooperative-sticky consumer group on shutdown even when the revoke-time
# offset commit is still in flight after the assignment is gone (slow coordinator path).
#
# Karafka talks to the broker through a proxy on the `DELAYED` listener. On shutdown, the proxy
# holds the `OffsetCommit` that librdkafka sends after the unassign until Karafka either pings
# again with an empty assignment or closes the client, so the commit is in flight when the
# assignment empties. When the client closes before that commit returns, librdkafka never sends
# the `LeaveGroup`, and the other member gets the partitions only after `session.timeout.ms`.

require "socket"

SESSION_TIMEOUT_MS = 30_000

# Forwards traffic to the broker `DELAYED` listener and can hold client `OffsetCommit` requests
class CommitHoldingProxy
  OFFSET_COMMIT_API_KEY = 8

  # Time for librdkafka to start the close after `#close` was called
  CLOSE_RELEASE_DELAY = 1

  private_constant :OFFSET_COMMIT_API_KEY, :CLOSE_RELEASE_DELAY

  # @param port [Integer] port to listen on (the `DELAYED` advertised port)
  # @param target_port [Integer] broker port of the `DELAYED` listener
  def initialize(port, target_port)
    @server = TCPServer.new("127.0.0.1", port)
    @target_port = target_port
    @mutex = Mutex.new
    @released = ConditionVariable.new
    @holding = false
    @held = false

    Thread.new do
      loop { forward(@server.accept) }
    rescue IOError
      nil
    end
  end

  # Holds the next `OffsetCommit` request (and the requests after it on its connection)
  def hold!
    @mutex.synchronize { @holding = true }
  end

  # @return [Boolean] true when an `OffsetCommit` request is held now
  def held?
    @mutex.synchronize { @held }
  end

  # Lets the held requests through and stops holding
  def release!
    @mutex.synchronize do
      @holding = false
      @released.broadcast
    end
  end

  # Releases after librdkafka started the close
  def release_after_close!
    Thread.new do
      sleep(CLOSE_RELEASE_DELAY)
      release!
    end
  end

  private

  # @param client [TCPSocket]
  def forward(client)
    upstream = TCPSocket.new("127.0.0.1", @target_port)

    Thread.new do
      buffer = "".b

      loop do
        buffer << client.readpartial(65_536)

        while buffer.bytesize >= 4 && buffer.bytesize >= 4 + buffer.unpack1("N")
          request = buffer.slice!(0, 4 + buffer.unpack1("N"))
          wait_if_held(request.unpack1("@4n"))
          upstream.write(request)
        end
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

  # @param api_key [Integer] Kafka request api key
  def wait_if_held(api_key)
    return unless api_key == OFFSET_COMMIT_API_KEY

    @mutex.synchronize do
      return unless @holding

      @held = true
      DT[:held_commits] << true
      @released.wait(@mutex) while @holding
      @held = false
    end
  end
end

PROXY = CommitHoldingProxy.new(9097, 9096)

# Drives the proxy from the stop loop steps, so the commit is in flight when the assignment empties
module CommitHolding
  def ping
    PROXY.release! if PROXY.held? && assignment.empty?

    super
  end

  def close
    PROXY.release_after_close!

    super
  end

  private

  def unsubscribe
    DT[:unsubscribed] = true

    super
  end
end

# Holds the commit that librdkafka sends for the revoked partitions after the unassign. Karafka
# commits synchronously before the unassign, so that commit is not held.
module UnassignCommitHolding
  def rd_kafka_incremental_unassign(*)
    PROXY.hold! if DT.key?(:unsubscribed)

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(CommitHolding)
Rdkafka::Bindings.singleton_class.prepend(UnassignCommitHolding)

setup_karafka do |config|
  config.kafka[:"bootstrap.servers"] = "127.0.0.1:9097"
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
  config.kafka[:"session.timeout.ms"] = SESSION_TIMEOUT_MS
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
    DT[:consumed_shared] = true if DT.key?(:shared)
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

# Keeps fresh offsets stored, so the revoke-time commits have offsets to commit
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
  DT.key?(:consumed_shared)
end

DT[:stopped_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)

other.join
feeder.join
producer.close

assert DT.key?(:held_commits)
assert DT.key?(:takeover)
assert DT[:takeover] < SESSION_TIMEOUT_MS / 2_000.0
