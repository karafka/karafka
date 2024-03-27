# frozen_string_literal: true

# When consumer uses patterns and same pattern matches the DLQ, messages may be self-consumed
# creating endless loop. Not something you want.

TOPIC_NAME = "not-funny-at-all-#{SecureRandom.uuid}".freeze

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << topic.name

    raise
  end
end

draw_routes(create_topics: false) do
  pattern(/#{TOPIC_NAME}/) do
    consumer Consumer

    dead_letter_queue(
      topic: "#{TOPIC_NAME}.dlq",
      max_retries: 1,
      independent: true
    )
  end
end

# No spec needed because finishing condition acts as a guard
start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many(TOPIC_NAME, DT.uuids(1))
    @created = true
  end

  DT[0].uniq.size >= 2
end
