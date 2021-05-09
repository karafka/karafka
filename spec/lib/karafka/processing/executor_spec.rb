# frozen_string_literal: true

RSpec.describe_current do
  subject(:executor) { described_class.new(group_id, client, topic, pause) }

  let(:group_id) { rand.to_s }
  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:topic) { build(:routing_topic) }
  let(:pause) { Karafka::TimeTrackers::Pause.new }

  describe '#id' do
    let(:executor2) { described_class.new(group_id, client, topic, pause) }

    it { expect(executor.id).to be_a(String) }

    it 'expect not to be the same between executors' do
      expect(executor.id).not_to eq(executor2.id)
    end
  end

  describe '#group_id' do
    it { expect(executor.group_id).to eq(group_id) }
  end

  describe '#consume' do
    let(:messages) { [build(:kafka_fetched_message)] }
    let(:received_at) { Time.now }
    let(:consumer) do
      ClassBuilder.inherit(topic.consumer) do
        def consume
        end
      end.new
    end

    before do
      allow(topic.consumer).to receive(:new).and_return(consumer)
      allow(consumer).to receive(:on_consume)
    end

    it { expect { executor.consume(messages, received_at) }.not_to raise_error }

    it 'expect to run the consumer appropriate method' do
      executor.consume(messages, received_at)
      expect(consumer).to have_received(:on_consume).with(no_args)
    end

    it 'expect to build appropriate messages batch' do
      executor.consume(messages, received_at)
      expect(consumer.messages.first.raw_payload).to eq(messages.first.payload)
    end

    it 'expect to build metadata with proper details' do
      executor.consume(messages, received_at)
      expect(consumer.messages.metadata.scheduled_at).to eq(received_at)
      expect(consumer.messages.metadata.topic).to eq(topic.name)
    end
  end

  describe '#revoked' do
    pending
  end

  describe '#shutdown' do
    pending
  end
end
