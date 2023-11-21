# frozen_string_literal: true

FactoryBot.define do
  factory :routing_subscription_group, class: 'Karafka::Routing::SubscriptionGroup' do
    sequence(:position)
    topics { Karafka::Routing::Topics.new([build(:routing_topic)]) }

    skip_create

    initialize_with do
      instance = new(position, topics)
      topics.each { |topic| topic.subscription_group = instance }
      instance
    end
  end
end
