# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This spec verifies that VP strategy works correctly when external libraries monkey-patch
# the Messages#each method (e.g., for tracing/instrumentation purposes).
#
# The VP strategy internally uses messages.raw.map(&:offset) which bypasses the patched each
# method by accessing the underlying array directly.
#
# @see https://github.com/karafka/karafka/issues/2939

setup_karafka do |config|
  config.concurrency = 5
end

# Simulation of external Messages#each patch (like tracing libraries do)
# This tracks when #each is called to verify internal VP code doesn't trigger it
module ExternalEachPatchSimulationVp
  def each(&)
    caller_location = caller_locations(1, 10).find do |loc|
      loc.path.include?('karafka') && !loc.path.include?('spec')
    end

    DT[:each_calls] << {
      caller: caller_location&.label,
      path: caller_location&.path,
      from_vp_strategy: caller_location&.path&.include?('strategies/vp')
    }

    super
  end
end

# Apply the external patch simulation
Karafka::Messages::Messages.prepend(ExternalEachPatchSimulationVp)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:consumed].size >= 20
end

assert_equal 20, DT[:consumed].uniq.size, 'All messages should be consumed'

# Verify that #each was NOT called from VP strategy code
vp_strategy_calls = DT[:each_calls].select { |call| call[:from_vp_strategy] }

assert vp_strategy_calls.empty?, <<~MSG
  VP strategy should not trigger patched #each method.
  Found #{vp_strategy_calls.size} calls from VP strategy code:
  #{vp_strategy_calls.map { |c| "  - #{c[:caller]} at #{c[:path]}" }.join("\n")}

  This causes issues with external instrumentation libraries creating unwanted spans.
  Fix: Use messages.raw.map(&:offset) instead of messages.map(&:offset)
MSG

# Verify that #each WAS called from user code
user_calls = DT[:each_calls].reject { |call| call[:from_vp_strategy] }
assert user_calls.any?, 'User code should trigger the patched #each method'
