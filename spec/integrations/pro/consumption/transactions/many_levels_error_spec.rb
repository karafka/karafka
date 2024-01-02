# frozen_string_literal: true

# If transaction fails even if nested blocks, it should not mark as nested transactions do nothing
# except code yielding

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    begin
      transaction do
        transaction do
          transaction do
            producer.produce_async(topic: DT.topic, payload: rand.to_s)
            mark_as_consumed(messages.first, messages.first.offset.to_s)

            raise StandardError
          end
        end
      end
    rescue StandardError => e
      p e
      DT[:metadata] << offset_metadata
      DT[:done] = true
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal '', DT[:metadata].first
