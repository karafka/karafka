# frozen_string_literal: true

# Share group (KIP-932) dead letter queue and records settling work correctly when external
# libraries monkey-patch Messages#each (e.g. for tracing). Internal code iterates the raw array, so
# only user code triggers the patched method.
#
# @see https://github.com/karafka/karafka/issues/2939

setup_karafka(allow_errors: %w[consumer.consume.error])

# Simulation of external Messages#each patch (like tracing libraries do)
module ExternalEachPatchSimulationShareDlq
  def each(&)
    # Immediate caller: user code lives in this spec file, internal code under lib/
    DT[:each_calls] << caller_locations(1, 1).first.path

    super
  end
end

Karafka::Messages::Messages.prepend(ExternalEachPatchSimulationShareDlq)

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.raw_payload == "poison"

      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 2)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

produce_many(DT.topics[0], ["poison"] + DT.uuids(4))

start_karafka_and_wait_until do
  DT[:dispatched].include?("poison")
end

internal_calls = DT[:each_calls].select { |path| path.include?("/lib/karafka/") }

assert internal_calls.empty?, internal_calls.uniq.join("\n")
assert DT[:each_calls].any?
