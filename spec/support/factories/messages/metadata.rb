# frozen_string_literal: true

FactoryBot.define do
  factory :messages_metadata, class: 'Karafka::Messages::Metadata' do
    skip_create

    partition { 0 }
    topic { 'topic' }
    sequence(:offset) { |nr| nr }

    initialize_with do
      new(partition: partition, topic: topic, offset: 0)
    end
  end
end
