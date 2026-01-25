# frozen_string_literal: true

# Karafka should support KIP-82 and should be able to both read and write array headers

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:headers] << message.headers
    end
  end
end

draw_routes(Consumer)

HEADERS = { "a" => "b", "c" => %w[d e] }.freeze

Karafka.producer.produce_sync(
  topic: DT.topic,
  payload: "",
  headers: HEADERS
)

start_karafka_and_wait_until do
  DT.key?(:headers)
end

assert_equal DT[:headers].first, HEADERS
