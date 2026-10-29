# frozen_string_literal: true

# Share group (KIP-932) consumers should be able to use a transactional producer to forward
# records. Records whose transaction was aborted are released and forwarded again on redelivery,
# so a downstream `read_committed` share group sees every record exactly once despite the aborts.

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
end

class Forwarder < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      # Abort the first delivery of every third record
      if (message.raw_payload.to_i % 3).zero? && message.metadata.delivery_count.to_i <= 1
        producer.transaction do
          producer.produce_async(topic: DT.topics[1], payload: message.raw_payload)

          raise WaterDrop::AbortTransaction
        end

        DT[:aborted] << message.raw_payload
        mark_as_released(message)

        next
      end

      producer.transaction do
        producer.produce_async(topic: DT.topics[1], payload: message.raw_payload)
      end

      mark_as_accepted(message)
    end
  end
end

class Collector < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:collected] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Forwarder
    end
  end

  share_group DT.groups[2] do
    topic DT.topics[1] do
      consumer Collector
    end
  end
end

setup_share_group(DT.topics[0], DT.groups[0])
setup_share_group(
  DT.topics[1],
  DT.groups[2],
  configs: { "share.isolation.level" => "read_committed" }
)

elements = (1..12).map(&:to_s)

Karafka.producer.transaction do
  elements.each { |element| Karafka.producer.produce_async(topic: DT.topics[0], payload: element) }
end

start_karafka_and_wait_until do
  DT[:collected].size >= elements.size && sleep(1)
end

assert_equal elements.sort, DT[:collected].sort
assert_equal elements.size, DT[:collected].uniq.size
assert !DT[:aborted].empty?
