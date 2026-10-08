# frozen_string_literal: true

# When all partitions of a topic are revoked, the listener must drop that topic from both its
# coordinators buffer (`CoordinatorsBuffer#@coordinators`, #3379) and its pauses manager
# (`PausesManager#@pauses`, #3318). Otherwise both maps grow with every rebalance for topics that
# are never reassigned (regex subscriptions, deleted topics, long-running processes). Both fixes are
# unit-tested by calling `#revoke` directly - this spec guards that the real revocation flow
# (rebalance manager -> listener -> buffers) still reaches the pruning code.
#
# Four single-partition topics are consumed and paused once, and a second consumer then repeatedly
# joins the group, taking over whole topics with round-robin assignment, and leaves. While it holds
# them, the Karafka listener must keep no state for any of those topics.

setup_karafka do |config|
  config.kafka[:"partition.assignment.strategy"] = "roundrobin"
end

ROUNDS = 3

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:paused].include?(topic.name)

    DT[:paused] << topic.name
    # Short pause so the partition gets a pause tracker that is used and then resumed well before
    # any revocation happens
    pause(messages.last.offset + 1, 100)
  end
end

draw_topics do
  DT.topics.first(4).each do |topic_name|
    topic topic_name do
      partitions 1
    end
  end
end

draw_routes do
  DT.topics.first(4).each do |topic_name|
    topic topic_name do
      consumer Consumer
    end
  end
end

TOPICS = DT.topics.first(4)

Thread.new do
  loop do
    TOPICS.each { |topic_name| produce(topic_name, "1") }

    sleep(0.2)
  rescue WaterDrop::Errors::ProducerClosedError, Rdkafka::ClosedProducerError
    break
  end
end

# Topics tracked by the listener right now, as seen by its coordinators buffer and pauses manager
def tracked_state
  listener = Karafka::Server.listeners.first
  buffer = listener.coordinators
  coordinators = buffer.instance_variable_get(:@coordinators).dup
  pauses = buffer.instance_variable_get(:@pauses_manager).instance_variable_get(:@pauses).dup

  {
    coordinators: coordinators.keys,
    pauses: pauses.keys.map(&:name)
  }
end

# Polls for the given time (polling returns early when messages are available)
def poll_for(consumer, seconds)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

  consumer.poll(100) while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
end

other = Thread.new do
  sleep(0.1) until DT[:paused].size == TOPICS.size

  consumer = setup_rdkafka_consumer("partition.assignment.strategy": "roundrobin")

  ROUNDS.times do
    consumer.subscribe(*TOPICS)

    consumer.poll(1_000) while consumer.assignment.empty?

    # Give the Karafka listener a few poll cycles to process the revocation
    poll_for(consumer, 5)

    DT[:rounds] << {
      taken: consumer.assignment.to_h.keys,
      karafka: tracked_state
    }

    consumer.unsubscribe

    # Let Karafka reclaim and resume consuming all the topics before the next round
    poll_for(consumer, 5)
  end

  consumer.close
end

start_karafka_and_wait_until do
  DT[:rounds].size >= ROUNDS
end

other.join

DT[:rounds].each do |round|
  taken = round[:taken]

  # Sanity: the other consumer took over whole topics, so Karafka had all partitions of them revoked
  assert !taken.empty?, round
  assert taken.size < TOPICS.size, round

  assert_equal [], taken & round[:karafka][:coordinators], round
  assert_equal [], taken & round[:karafka][:pauses], round
end
