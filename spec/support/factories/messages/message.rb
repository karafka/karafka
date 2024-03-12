# frozen_string_literal: true

FactoryBot.define do
  factory :messages_message, class: 'Karafka::Messages::Message' do
    skip_create

    transient do
      sequence(:topic) { |nr| "topic#{nr}" }
      partition { 0 }
      timestamp { Time.now.utc }
      key { nil }
      headers { {} }
    end

    raw_payload { '{}' }

    metadata do
      build(
        :messages_metadata,
        topic: topic,
        partition: partition,
        timestamp: timestamp,
        key: key,
        headers: headers
      )
    end

    initialize_with do
      new(raw_payload, metadata)
    end
  end
end
