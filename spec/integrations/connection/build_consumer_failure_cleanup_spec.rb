# frozen_string_literal: true

# When Karafka::Connection::Client#build_consumer raises after allocating the native
# rdkafka consumer (e.g., subscribe fails due to transient broker issues like DNS
# resolution failures, unknown_topic_or_part, unreleased_instance_id for static
# group membership, etc.), it must clean up:
#
#   1. The allocated native rd_kafka_t handle (and its internal pipe FDs + threads)
#   2. The statistics/error/oauthbearer callback registry entries keyed by sg.id
#
# Without this cleanup:
#   - Pipe FDs leak (the oauth callback holds a strong ref to the consumer,
#     pinning it from GC / finalizer-driven destruction)
#   - Stale callback entries remain in the global registries
#
# A flapping broker or DNS hiccup can cause listeners to rescue and retry
# build_consumer many times. Under load this matches the reported prod FD growth
# (thousands of leaked handles with ~2 pipe FDs each) from 132 subscription
# groups × transient broker issues × hours.

LINUX = RUBY_PLATFORM.include?("linux")

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    nil
  end
end

draw_routes(Consumer)

# Force subscribe to always raise. This simulates the failure path inside
# build_consumer after the consumer has been allocated and the 3 callback
# entries have been registered.
module SubscribeFailure
  # unknown_topic_or_part (3) is a realistic transient failure for subscribe
  def subscribe(*)
    raise Rdkafka::RdkafkaError.new(3)
  end
end

Rdkafka::Consumer.prepend(SubscribeFailure)

def count_pipe_fds
  Dir.glob("/proc/self/fd/*").count do |fd_path|
    File.readlink(fd_path).start_with?("pipe:")
  rescue Errno::ENOENT
    false
  end
end

def callback_registries
  {
    statistics: Karafka::Core::Instrumentation
      .statistics_callbacks.instance_variable_get(:@callbacks),
    error: Karafka::Core::Instrumentation
      .error_callbacks.instance_variable_get(:@callbacks),
    oauth: Karafka::Core::Instrumentation
      .oauthbearer_token_refresh_callbacks.instance_variable_get(:@callbacks)
  }
end

subscription_group = Karafka::App.subscription_groups.values.flatten.first
sg_id = subscription_group.id

# Let producer/admin/bootstrap settle before we snapshot FDs
sleep(1)
GC.start
sleep(0.5)

baseline_pipes = count_pipe_fds if LINUX

# Run many failing build_consumer attempts. Each one allocates a native consumer,
# registers 3 callbacks, then raises inside subscribe. Correct behavior is to
# clean everything up on the raise path.
cycles = 10
raised_count = 0

cycles.times do
  client = Karafka::Connection::Client.new(subscription_group, -> { true })

  begin
    client.send(:build_consumer)
  rescue Rdkafka::RdkafkaError
    raised_count += 1
  end

  # Registries must not carry entries for this subscription group after the
  # failed build. Before the fix, all 3 entries remain and the oauth one holds
  # a strong ref to the leaked consumer.
  registries = callback_registries

  assert(
    !registries[:statistics].key?(sg_id),
    "statistics_callbacks leaked entry for #{sg_id} after failed build_consumer"
  )
  assert(
    !registries[:error].key?(sg_id),
    "error_callbacks leaked entry for #{sg_id} after failed build_consumer"
  )
  assert(
    !registries[:oauth].key?(sg_id),
    "oauthbearer_token_refresh_callbacks leaked entry for #{sg_id} " \
      "after failed build_consumer (this pins the native consumer from GC)"
  )
end

assert_equal(cycles, raised_count, "Every build_consumer attempt should raise")

# Force GC so finalizers for any released consumers can run, then re-measure.
# With the fix, all consumers are explicitly closed so this is a no-op.
# Without the fix, the most recent leaked consumer is still strong-ref'd by
# the oauth callback and cannot be collected even here.
GC.start
sleep(1)
GC.start
sleep(0.5)

if LINUX
  after_pipes = count_pipe_fds
  growth = after_pipes - baseline_pipes

  # Each leaked consumer carries at least 2 pipe FDs (wakeup pipe pair) plus
  # internal plumbing. 10 cycles × ≥2 = ≥20 FDs worst case before fix.
  # After fix: ~0. Allow a small tolerance for unrelated infrastructure churn.
  assert(
    growth <= 4,
    "Pipe FDs grew by #{growth} over #{cycles} failed build_consumer attempts " \
      "(#{baseline_pipes} -> #{after_pipes}) — native rdkafka handles leaked " \
      "from build_consumer error path"
  )
end
