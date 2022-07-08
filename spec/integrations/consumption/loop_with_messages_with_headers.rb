# frozen_string_literal: true

# Karafka should be able to consume messages in a loop
# Messages can have headers that should be accessible to use

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[:headers] << messages.last.headers.fetch('iteration').to_i
    end

    producer.produce_sync(
      topic: DataCollector.topic,
      payload: rand.to_s,
      headers: { 'iteration' => (messages.last.headers.fetch('iteration').to_i + 1).to_s }
    )
  end
end

draw_routes(Consumer)

Karafka.producer.produce_sync(
  topic: DataCollector.topic,
  payload: rand.to_s,
  headers: { 'iteration' => '0' }
)

start_karafka_and_wait_until do
  DataCollector[:headers].size >= 20
end


i = 0

DataCollector[:headers].each do |iteration|
  assert_equal i, iteration
  i += 1
end
