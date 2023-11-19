# frozen_string_literal: true

FactoryBot.define do
  factory :messages_message, class: 'Karafka::Messages::Message' do
    skip_create

    transient do
      sequence(:topic) { |nr| "topic#{nr}" }
      partition { 0 }
      timestamp { Time.now.utc }
    end

    raw_payload { '{}' }

    metadata do
      build(
        :messages_metadata,
        topic: topic,
        partition: partition,
        timestamp: timestamp
      )
    end

    initialize_with do
      new(raw_payload, metadata)
    end
  end
end
