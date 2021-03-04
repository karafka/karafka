# frozen_string_literal: true

FactoryBot.define do
  factory :routing_topic, class: 'Karafka::Routing::Topic' do
    consumer_group { build(:routing_consumer_group) }
    name { 'test' }
    consumer { Class.new(Karafka::BaseConsumer) }

    skip_create

    initialize_with do
      instance = new(name, consumer_group)

      instance.tap do |topic|
        topic.consumer = consumer
      end
    end
  end
end
