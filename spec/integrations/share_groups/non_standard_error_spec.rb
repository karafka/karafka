# frozen_string_literal: true

# Share group (KIP-932) non-StandardError (like NotImplementedError) raised in `#consume` is
# reported and does not crash the process. The batch records are released and redelivered, so
# nothing is lost.

setup_karafka(allow_errors: %w[consumer.consume.error])

SuperException = Class.new(Exception)

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << [event[:type], event[:error].class]
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      # Fail only on the first encounter of each kind so the redelivery processes fine
      if message.raw_payload == "poison" && !DT.key?(:poisoned)
        DT[:poisoned] = true
        raise NotImplementedError, "non-StandardError raised mid-consume"
      end

      if message.raw_payload == "critical" && !DT.key?(:critical)
        DT[:critical] = true
        raise SuperException
      end

      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(4)
payloads = elements.first(2) + %w[poison] + elements.last(2) + %w[critical]
produce_many(DT.topic, payloads)

raised = false

begin
  start_karafka_and_wait_until do
    DT[:accepted].uniq.size >= payloads.size
  end
rescue SuperException, NotImplementedError
  raised = true
end

assert_equal false, raised
assert_equal payloads.sort, DT[:accepted].uniq.sort
assert DT[:errors].include?(["consumer.consume.error", NotImplementedError])
assert DT[:errors].include?(["consumer.consume.error", SuperException])
assert_equal ["consumer.consume.error"], DT[:errors].map(&:first).uniq

%w[poison critical].each do |payload|
  counts = DT[:deliveries].select { |delivered, _| delivered == payload }.map(&:last)

  assert counts.size >= 2
  assert counts.max >= 2
end
