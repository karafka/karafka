# frozen_string_literal: true

# When we cancel future already loaded daily message, it should not go out

setup_karafka

draw_routes do
  scheduled_messages(topics_namespace: DT.topic)

  topic DT.topic do
    active(false)
  end
end

message = {
  topic: DT.topic,
  key: '0',
  payload: 'payload'
}

proxy = Karafka::Pro::ScheduledMessages.schedule(
  message: message,
  # We give the consumer enough time to start working
  epoch: Time.now.to_i + 15,
  envelope: { topic: "#{DT.topic}messages", partition: 0 }
)

Karafka.producer.produce_sync(proxy)

start_karafka_and_wait_until(sleep: 1) do
  state = Karafka::Admin.read_topic("#{DT.topic}states", 0, 1).first

  next unless state

  if state.payload[:daily].first.last > 0 && !@cancelled
    @cancelled = true

    cancel = Karafka::Pro::ScheduledMessages.cancel(
      key: proxy[:key],
      envelope: { topic: "#{DT.topic}messages", partition: 0 }
    )

    Karafka.producer.produce_sync(cancel)
  end

  @cancelled && state.payload[:daily].first.last.zero?
end

# Nothing should have been dispatched
assert_equal Karafka::Admin.read_topic(DT.topic, 0, 1), []
