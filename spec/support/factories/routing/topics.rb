# frozen_string_literal: true

FactoryBot.define do
  factory :routing_topic, class: 'Karafka::Routing::Topic' do
    consumer_group { build(:routing_consumer_group) }
    name { 'test' }
    consumer { Class.new(Karafka::BaseConsumer) }
    backend { :inline }
    batch_consuming { true }
    responder { nil }

    skip_create

    initialize_with do
      instance = new(name, consumer_group)

      instance.tap do |topic|
        topic.consumer = consumer
        topic.backend = backend
        topic.batch_consuming = batch_consuming
        topic.responder = responder
      end
    end
  end
end
