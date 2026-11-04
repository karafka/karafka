# frozen_string_literal: true

# Share group (KIP-932) records support KIP-82 array headers.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:headers] << message.headers
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

HEADERS = { "a" => "b", "c" => %w[d e] }.freeze

Karafka.producer.produce_sync(
  topic: DT.topic,
  payload: "",
  headers: HEADERS
)

start_karafka_and_wait_until do
  DT.key?(:headers)
end

assert_equal HEADERS, DT[:headers].first
