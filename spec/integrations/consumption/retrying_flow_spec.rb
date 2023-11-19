# frozen_string_literal: true

# Non-errored flow should not be in the retrying state, while consecutive retries should

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << [retrying?, attempt]

    raise StandardError
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].count >= 5
end

DT[0].each_with_index do |aggro, index|
  assert_equal aggro, [index.positive?, index + 1]
end
