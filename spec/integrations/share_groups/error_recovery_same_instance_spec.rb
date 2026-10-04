# frozen_string_literal: true

# Share group (KIP-932) recovers from a non-critical error with the same consumer instance: the
# released records are redelivered to it and an error event with the details is emitted.

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    @count ||= 0
    @count += 1

    messages.each { |message| DT[:consumed] << message.raw_payload }
    DT[:consumers] << object_id

    raise StandardError if @count == 1

    messages.each { |message| mark_as_accepted(message) }
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

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # We have 5 records but the first batch fails and is redelivered, so it needs to be minimum 6
  DT[:consumed].size >= 6 && DT[:consumed].uniq.size >= 5
end

assert_equal elements.sort, DT[:consumed].uniq.sort
assert_equal 1, DT[:consumers].uniq.size
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal "consumer.consume.error", DT[:errors].first[:type]
assert_equal "error.occurred", DT[:errors].first.id
