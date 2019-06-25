# frozen_string_literal: true

RSpec.describe Karafka::Connection::BatchDelegator do
  subject(:delegator) { described_class }

  let(:group_id) { consumer_group.id }
  let(:topic) { build(:routing_topic, consumer_group: consumer_group) }
  let(:consumer_instance) { consumer_group.topics[0].consumer.new(topic) }
  let(:kafka_batch) { build(:kafka_fetched_batch) }

  before do
    allow(Karafka::Persistence::Topics).to receive(:fetch).and_return(consumer_group.topics[0])
    allow(Karafka::Persistence::Consumers).to receive(:fetch).and_return(consumer_instance)
  end

  context 'when batch_consuming true' do
    before { allow(consumer_instance).to receive(:call) }

    let(:consumer_group) do
      Karafka::Routing::Builder.instance.draw do
        topic :topic_name1 do
          consumer Class.new(Karafka::BaseConsumer)
          batch_consuming true
        end
      end

      Karafka::Routing::Builder.instance.last
    end

    it 'expect to run without errors' do
      expect { delegator.call(group_id, kafka_batch) }.not_to raise_error
    end
  end

  context 'when batch_consuming false' do
    before { allow(consumer_instance).to receive(:call).twice }

    let(:consumer_group) do
      Karafka::Routing::Builder.instance.draw do
        topic :topic_name1 do
          consumer Class.new(Karafka::BaseConsumer)
          batch_consuming false
        end
      end

      Karafka::Routing::Builder.instance.last
    end

    it 'expect to run without errors' do
      expect { delegator.call(group_id, kafka_batch) }.not_to raise_error
    end
  end
end
