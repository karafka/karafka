# frozen_string_literal: true

# Share group (KIP-932) consumes records produced with the gzip, lz4 and snappy compression
# codecs.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

CODECS = %w[gzip lz4 snappy].freeze

draw_routes(create_topics: false) do
  share_group DT.group do
    CODECS.each_with_index do |_codec, index|
      topic DT.topics[index] do
        consumer Consumer
      end
    end
  end
end

elements = {}

CODECS.each_with_index do |codec, index|
  topic_name = DT.topics[index]
  setup_share_group(topic_name)
  elements[topic_name] = DT.uuids(10)

  producer = WaterDrop::Producer.new do |config|
    config.kafka = Karafka::App.config.kafka.merge("compression.codec": codec)
  end

  producer.produce_many_sync(
    elements[topic_name].map { |payload| { topic: topic_name, payload: payload } }
  )

  producer.close
end

start_karafka_and_wait_until do
  elements.all? { |topic_name, payloads| DT[topic_name].size >= payloads.size }
end

elements.each do |topic_name, payloads|
  assert_equal payloads.sort, DT[topic_name].sort
end
