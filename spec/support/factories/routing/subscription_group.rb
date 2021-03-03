# frozen_string_literal: true

FactoryBot.define do
  factory :routing_subscription_group, class: 'Karafka::Routing::SubscriptionGroup' do
    topics { [build(:routing_topic)] }

    skip_create

    initialize_with do
      new(topics)
    end
  end
end
