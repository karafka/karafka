# frozen_string_literal: true

FactoryBot.define do
  factory :routing_consumer_group, class: 'Karafka::Routing::ConsumerGroup' do
    name { 'group-name' }

    skip_create

    initialize_with do
      new(name)
    end
  end
end
