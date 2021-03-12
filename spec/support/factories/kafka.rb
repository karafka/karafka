# frozen_string_literal: true

FactoryBot.define do
  factory :kafka_fetched_message, class: 'OpenStruct' do
    payload { rand.to_s }
    key { nil }
    offset { 0 }
    timestamp { Time.now }
    topic { rand.to_s }
    partition { 0 }
    headers { {} }

    skip_create

    initialize_with { new(**attributes) }
  end
end
