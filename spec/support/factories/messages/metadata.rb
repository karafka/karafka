# frozen_string_literal: true

FactoryBot.define do
  factory :messages_metadata, class: 'Karafka::Messages::Metadata' do
    skip_create

    partition { 0 }
    topic { 'topic' }
    offset { 0 }

    initialize_with do
      new(partition: partition, topic: topic, offset: 0)
    end
  end
end
