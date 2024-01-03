# frozen_string_literal: true

# Running a transaction that does not publish data and does not store offsets should be ok

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      nil
    end

    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end
