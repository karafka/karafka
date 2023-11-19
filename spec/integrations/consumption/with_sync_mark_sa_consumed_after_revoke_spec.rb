# frozen_string_literal: true

# When we've lost a topic and end up with an `unknown_member_id`, we should handle that
# gracefully while running `mark_as_consumed!`.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      if DT.key?(:pre_closed_mark) && !DT.key?(:post_closed_mark)
        sleep(0.1) until DT.key?(:second_closed)
        DT[:post_closed_mark] = mark_as_consumed!(message)
        return
      end

      DT[:pre_closed_mark] = mark_as_consumed!(message)
    end
  end
end

draw_routes(Consumer)

other_consumer = Thread.new do
  sleep(0.1) until DT.key?(:pre_closed_mark)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)
  consumer.each { break }
  consumer.close

  DT[:second_closed] = true
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(20))
  sleep(1)

  DT.key?(:post_closed_mark)
end

other_consumer.join

assert_equal DT[:post_closed_mark], false
assert_equal DT[:pre_closed_mark], true
