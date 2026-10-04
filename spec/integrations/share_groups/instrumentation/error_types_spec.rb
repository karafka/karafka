# frozen_string_literal: true

# Share group (KIP-932) consumer errors should be published with their types and the share
# consumer as the caller: consumer.initialized.error, consumer.consume.error and
# consumer.shutdown.error. The process keeps consuming despite them.

setup_karafka(allow_errors: true)

class Consumer < Karafka::ShareConsumer
  def initialized
    raise StandardError, "initialized"
  end

  def consume
    # Fail the first delivery so the records get released and redelivered
    unless DT.key?(:failed)
      DT[:failed] = true
      raise StandardError, "consume"
    end

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end

  def shutdown
    raise StandardError, "shutdown"
  end
end

Karafka::App.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 5
end

assert_equal elements.sort, DT[:accepted].uniq.sort

expected = %w[
  consumer.consume.error
  consumer.initialized.error
  consumer.shutdown.error
]

assert_equal expected, DT[:errors].map { |event| event[:type] }.uniq.sort

DT[:errors].each do |event|
  assert event[:caller].is_a?(Consumer)
  assert_equal event[:type].split(".")[1], event[:error].message
end
