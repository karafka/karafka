# frozen_string_literal: true

RSpec.describe Karafka::Connection::MessageDelegator do
  subject(:delegator) { described_class }

  let(:group_id) { consumer_group.id }
  let(:topic) { build(:routing_topic) }
  let(:consumer_instance) { consumer_group.topics[0].consumer.new(topic) }
  let(:raw_message) { build(:kafka_fetched_message) }
  let(:consumer_group) do
    Karafka::Routing::Builder.instance.draw do
      topic :topic_name1 do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end

    Karafka::Routing::Builder.instance.last
  end

  before do
    allow(Karafka::Persistence::Topic).to receive(:fetch).and_return(consumer_group.topics[0])
    allow(Karafka::Persistence::Consumer).to receive(:fetch).and_return(consumer_instance)
    allow(consumer_instance).to receive(:call)
  end

  it 'expect to run without errors' do
    expect { delegator.call(group_id, raw_message) }.not_to raise_error
  end
end
