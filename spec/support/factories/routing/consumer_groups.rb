# frozen_string_literal: true

FactoryBot.define do
  factory :routing_consumer_group, class: 'Karafka::Routing::ConsumerGroup' do
    name { 'group-name' }
    batch_fetching { false }

    skip_create

    initialize_with do
      instance = new(name)

      instance.tap do |consumer_group|
        consumer_group.batch_fetching = batch_fetching
      end
    end
  end
end
