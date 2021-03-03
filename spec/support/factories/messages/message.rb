# frozen_string_literal: true

FactoryBot.define do
  factory :messages_message, class: 'Karafka::Messages::Message' do
    skip_create

    raw_payload { '{}' }
    metadata { build(:messages_metadata) }

    initialize_with do
      new(raw_payload, metadata)
    end
  end
end
