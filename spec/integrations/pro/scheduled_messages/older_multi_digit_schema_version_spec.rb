# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# A scheduled message stamped with an older (compatible) schema version must be accepted and
# dispatched also when the version segments differ in digit count. Schema versions are semver,
# so "1.2.0" is older than "1.10.0" while being lexicographically greater. Prior to the fix,
# versions were compared as strings and such a message was rejected as incompatible, breaking
# all older scheduled messages after a consumer upgrade past a two-digit schema segment.

setup_karafka(allow_errors: true)

class Listener
  def on_error_occurred(event)
    DT[:errors] << event[:error]
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:dispatched] << message.raw_payload }
  end
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    consumer Consumer
  end
end

# Simulate a message produced by an older library version with a semver-lower but
# lexicographically greater schema version than the consumer's
Karafka::Pro::ScheduledMessages.send(:remove_const, :SCHEMA_VERSION)
Karafka::Pro::ScheduledMessages.const_set(:SCHEMA_VERSION, "1.2.0")

proxy = Karafka::Pro::ScheduledMessages.schedule(
  message: { topic: DT.topics[1], payload: "older-schema-payload" },
  epoch: Time.now.to_i + 2,
  envelope: { topic: DT.topics[0], partition: 0 }
)

Karafka.producer.produce_sync(proxy)

# Simulate the consumer running a newer library version with a two-digit schema segment
Karafka::Pro::ScheduledMessages.send(:remove_const, :SCHEMA_VERSION)
Karafka::Pro::ScheduledMessages.const_set(:SCHEMA_VERSION, "1.10.0")

incompatible = lambda do
  DT[:errors].any? do |error|
    error.is_a?(Karafka::Pro::ScheduledMessages::Errors::IncompatibleSchemaError)
  end
end

start_karafka_and_wait_until do
  DT.key?(:dispatched) || incompatible.call
end

assert_equal(
  false,
  incompatible.call,
  "older compatible schema version was rejected as incompatible (string comparison)"
)

assert_equal ["older-schema-payload"], DT[:dispatched]
