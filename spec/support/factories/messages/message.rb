# frozen_string_literal: true

FactoryBot.define do
  factory :messages_message, class: "Karafka::Messages::Message" do
    skip_create

    transient do
      sequence(:topic) { |nr| "topic#{nr}" }
      sequence(:offset) { |nr| nr }
      partition { 0 }
      timestamp { Time.now.utc }
      raw_key { nil }
      raw_headers { {} }
    end

    raw_payload { "{}" }

    metadata do
      build(
        :messages_metadata,
        topic: topic,
        partition: partition,
        timestamp: timestamp,
        raw_key: raw_key,
        offset: offset,
        raw_headers: raw_headers
      )
    end

    initialize_with do
      new(raw_payload, metadata)
    end
  end
end
