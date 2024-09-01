# frozen_string_literal: true

# When we cancel future already loaded daily message, it should not go out

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

message = {
  topic: DT.topics[1],
  key: '0',
  payload: 'payload'
}

proxy = Karafka::Pro::ScheduledMessages.schedule(
  message: message,
  # We give the consumer enough time to start working
  epoch: Time.now.to_i + 15,
  envelope: { topic: DT.topics[0], partition: 0 }
)

Karafka.producer.produce_sync(proxy)

start_karafka_and_wait_until(sleep: 1) do
  state = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).first

  next unless state

  if state.payload[:daily].first.last > 0 && !@cancelled
    @cancelled = true

    cancel = Karafka::Pro::ScheduledMessages.cancel(
      key: proxy[:key],
      envelope: { topic: DT.topics[0], partition: 0 }
    )

    Karafka.producer.produce_sync(cancel)
  end

  @cancelled && state.payload[:daily].first.last.zero?
end

# Nothing should have been dispatched
assert_equal Karafka::Admin.read_topic(DT.topics[1], 0, 1), []
