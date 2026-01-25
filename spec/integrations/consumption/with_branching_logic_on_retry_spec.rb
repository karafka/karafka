# frozen_string_literal: true

# We should be able to apply custom logic flow, when re-processing data after an error.

setup_karafka(allow_errors: true)

SuperStandardError = Class.new(StandardError)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise SuperStandardError if message.offset == 5 && !retrying?

      DT[:offsets] << message.offset

      mark_as_consumed(message)
    end
  end
end

draw_routes(Consumer)

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "consumer.consume.error"

  DT[:errors] << event[:error]
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].count >= 10
end

assert_equal true, DT[:errors].one?
assert_equal true, DT[:errors].first.instance_of?(SuperStandardError)
assert_equal DT[:offsets], (0..9).to_a
