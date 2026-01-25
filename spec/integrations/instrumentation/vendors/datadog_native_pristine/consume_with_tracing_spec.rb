# frozen_string_literal: true

# Karafka should integrate with Datadog native tracing and enable distributed tracing for
# message consumption

require "karafka"
require "datadog/auto_instrument"

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.raw_payload
    end
  end
end

setup_karafka

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

Datadog.configure do |c|
  c.tracing.instrument :karafka, enabled: true, distributed_tracing: true
end

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert Datadog::Tracing::Contrib::Karafka::Patcher.patched?
