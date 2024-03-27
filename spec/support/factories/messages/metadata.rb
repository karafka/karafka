# frozen_string_literal: true

FactoryBot.define do
  factory :messages_metadata, class: 'Karafka::Messages::Metadata' do
    skip_create

    sequence(:topic) { |nr| "topic-from-meta#{nr}" }
    sequence(:offset) { |nr| nr }
    partition { 0 }
    timestamp { Time.now.utc }
    deserializers do
      Karafka::Routing::Features::Deserializers::Config.new(
        active: true,
        payload: ->(message) { JSON.parse(message.raw_payload) },
        key: Karafka::Serialization::Passthrough::Deserializer.new,
        headers: Karafka::Serialization::Passthrough::Deserializer.new
      )
    end

    initialize_with do
      new(partition: partition, topic: topic, offset: 0, deserializers: deserializers)
    end
  end
end
