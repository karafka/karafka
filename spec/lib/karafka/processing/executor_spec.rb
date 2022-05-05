# frozen_string_literal: true

RSpec.describe_current do
  subject(:executor) { described_class.new(group_id, client, topic, pause) }

  let(:group_id) { rand.to_s }
  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:topic) { build(:routing_topic) }
  let(:pause) { build(:time_trackers_pause) }
  let(:messages) { [build(:kafka_fetched_message)] }
  let(:received_at) { Time.now }
  let(:consumer) do
    ClassBuilder.inherit(topic.consumer) do
      def consume; end
    end.new
  end

  before { allow(topic.consumer).to receive(:new).and_return(consumer) }

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

  describe '#prepare' do
    it { expect { executor.prepare(messages, received_at) }.not_to raise_error }

    it 'expect to build appropriate messages batch' do
      executor.prepare(messages, received_at)
      expect(consumer.messages.first.raw_payload).to eq(messages.first.payload)
    end

    it 'expect to build metadata with proper details' do
      executor.prepare(messages, received_at)
      expect(consumer.messages.metadata.scheduled_at).to eq(received_at)
      expect(consumer.messages.metadata.topic).to eq(topic.name)
    end
  end

  describe '#consume' do
    before do
      allow(consumer).to receive(:on_consume)
      executor.consume
    end

    it 'expect to run consumer' do
      expect(consumer).to have_received(:on_consume)
    end
  end

  describe '#revoked' do
    before { allow(consumer).to receive(:on_revoked) }

    context 'when the consumer was not yet used' do
      before { executor.revoked }

      it 'expect not to run consumer as it never received any messages' do
        expect(consumer).not_to have_received(:on_revoked)
      end
    end

    context 'when the consumer was in use and exists' do
      before do
        allow(consumer).to receive(:on_consume)
        executor.consume
        executor.revoked
      end

      it 'expect to run consumer' do
        expect(consumer).to have_received(:on_revoked).with(no_args)
      end
    end
  end

  describe '#shutdown' do
    before { allow(consumer).to receive(:on_shutdown) }

    context 'when the consumer was not yet used' do
      before { executor.shutdown }

      it 'expect not to run consumer as it never received any messages' do
        expect(consumer).not_to have_received(:on_shutdown)
      end
    end

    context 'when the consumer was in use and exists' do
      before do
        allow(consumer).to receive(:on_consume)
        executor.consume
        executor.shutdown
      end

      it 'expect to run consumer' do
        expect(consumer).to have_received(:on_shutdown).with(no_args)
      end
    end
  end
end
