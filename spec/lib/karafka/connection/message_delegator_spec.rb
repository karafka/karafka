# frozen_string_literal: true

RSpec.describe Karafka::Connection::MessageDelegator do
  subject(:delegator) { described_class }

  let(:group_id) { consumer_group.id }
  let(:topic_id) { consumer_group.topics[0].name }
  let(:consumer_instance) { consumer_group.topics[0].consumer.new }
  let(:raw_message_value) { rand }
  let(:raw_message) do
    Kafka::FetchedMessage.new(
      message: OpenStruct.new(
        value: raw_message_value,
        key: nil,
        offset: 0,
        create_time: Time.now
      ),
      topic: topic_id,
      partition: 0
    )
  end
  let(:consumer_group) do
    Karafka::Routing::Builder.instance.draw do
      topic :topic_name1 do
        consumer Class.new(Karafka::BaseConsumer)
        persistent false
      end
    end

    Karafka::Routing::Builder.instance.last
  end

  before do
    allow(Karafka::Persistence::Topic).to receive(:fetch).and_return(consumer_group.topics[0])
    allow(Karafka::Persistence::Consumer).to receive(:fetch).and_return(consumer_instance)
    allow(consumer_instance).to receive(:params_batch=).with([raw_message])
    allow(consumer_instance).to receive(:call)
  end

  it 'expect to run without errors' do
    expect { delegator.call(group_id, raw_message) }.not_to raise_error
  end
end
