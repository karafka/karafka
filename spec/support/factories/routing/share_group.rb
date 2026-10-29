# frozen_string_literal: true

FactoryBot.define do
  factory :routing_share_group, class: "Karafka::Routing::ShareGroups::Group" do
    name { "share-group-name" }

    skip_create

    initialize_with do
      new(name)
    end
  end

  factory :routing_share_topic, class: "Karafka::Routing::ShareGroups::Topic" do
    group { build(:routing_share_group) }
    name { "test" }
    consumer { Class.new(Karafka::ShareConsumer) }
    subscription_group { SecureRandom.hex(6) }
    subscription_group_details { { name: SecureRandom.uuid } }

    skip_create

    initialize_with do
      instance = new(name, group)

      instance.tap do |topic|
        topic.consumer = consumer
        topic.subscription_group = subscription_group
        topic.subscription_group_details = subscription_group_details
      end
    end
  end
end
