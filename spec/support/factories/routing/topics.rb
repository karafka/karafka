# frozen_string_literal: true

FactoryBot.define do
  factory :routing_topic, class: 'Karafka::Routing::Topic' do
    consumer_group { Karafka::Routing::ConsumerGroup.new('group-name') }
    name { 'test' }
    consumer { Class.new(Karafka::BaseConsumer) }

    skip_create

    initialize_with do
      consumer_class = consumer
      instance = new(name, consumer_group)

      instance.tap do |topic|
        topic.consumer = consumer_class
        topic.backend = :inline
      end
    end
  end
end
