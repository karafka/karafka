# frozen_string_literal: true

FactoryBot.define do
  factory :messages_metadata, class: 'Karafka::Messages::Metadata' do
    skip_create

    sequence(:topic) { |nr| "topic-from-meta#{nr}" }
    sequence(:offset) { |nr| nr }
    partition { 0 }
    deserializer { ->(message) { JSON.parse(message.raw_payload) } }

    initialize_with do
      new(partition: partition, topic: topic, offset: 0, deserializer: deserializer)
    end
  end
end
