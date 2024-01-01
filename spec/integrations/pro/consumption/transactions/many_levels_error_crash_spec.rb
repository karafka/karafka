# frozen_string_literal: true

# If transaction fails even if nested blocks, it should not mark as nested transactions do nothing
# except code yielding.
# On total crash offset should not be stored

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    transaction do
      transaction do
        transaction do
          producer.produce_async(topic: DT.topic, payload: rand.to_s)
          mark_as_consumed(messages.first, messages.first.offset.to_s)

          DT[:done] = true
          raise StandardError
        end
      end
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 0, fetch_first_offset
