# frozen_string_literal: true

FactoryBot.define do
  factory :routing_subscription_group, class: "Karafka::Routing::SubscriptionGroup" do
    sequence(:position)
    topics { Karafka::Routing::Topics.new([build(:routing_topic)]) }
    name { rand.to_s }

    skip_create

    initialize_with do
      topics.first.subscription_group_details = { name: name }
      instance = new(position, topics)
      topics.each { |topic| topic.subscription_group = instance }
      instance
    end
  end
end
