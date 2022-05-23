# frozen_string_literal: true

FactoryBot.define do
  factory :messages_message, class: 'Karafka::Messages::Message' do
    skip_create

    transient do
      sequence(:topic) { |nr| "topic#{nr}" }
      partition { 0 }
    end

    raw_payload { '{}' }
    metadata { build(:messages_metadata, topic: topic, partition: partition) }

    initialize_with do
      new(raw_payload, metadata)
    end
  end
end
