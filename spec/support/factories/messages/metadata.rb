# frozen_string_literal: true

FactoryBot.define do
  factory :messages_metadata, class: 'Karafka::Messages::Metadata' do
    skip_create

    partition { 0 }
    topic { 'topic' }

    initialize_with do
      new(partition: partition, topic: topic)
    end
  end
end
