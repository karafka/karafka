# frozen_string_literal: true

# Karafka should be able to recover from non-critical error with same consumer instance and it
# also should emit an event with error details that can be logged

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    messages.each { |message| DT[0] << message.raw_payload }
    DT[1] << object_id

    raise StandardError if @count == 1
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  # We have 5 messages but we retry thus it needs to be minimum 6
  DT[0].size >= 6
end

assert DT[0].size >= 6
assert_equal 1, DT[1].uniq.size
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal 'consumer.consume.error', DT[:errors].first[:type]
assert_equal 'error.occurred', DT[:errors].first.id
assert_equal 5, DT[0].uniq.size
