# frozen_string_literal: true

FactoryBot.define do
  factory :kafka_fetched_message, class: 'Kafka::FetchedMessage' do
    value { rand.to_s }
    key { nil }
    offset { 0 }
    create_time { Time.now }
    topic { rand.to_s }
    partition { 0 }
    headers { nil }

    skip_create

    initialize_with do
      new(
        message: OpenStruct.new(
          value: value,
          key: key,
          offset: offset,
          create_time: create_time,
          headers: headers
        ),
        topic: topic,
        partition: partition
      )
    end
  end

  factory :kafka_fetched_batch, class: 'Kafka::FetchedBatch' do
    topic { rand.to_s }
    partition { 0 }
    highwater_mark_offset { 0 }
    last_offset { 0 }
    messages do
      [
        build(:kafka_fetched_message, partition: partition, topic: topic),
        build(:kafka_fetched_message, partition: partition, topic: topic)
      ]
    end

    initialize_with { new(attributes) }
  end
end
