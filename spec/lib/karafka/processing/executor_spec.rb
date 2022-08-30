# frozen_string_literal: true

RSpec.describe_current do
  subject(:executor) { described_class.new(group_id, client, topic) }

  let(:group_id) { rand.to_s }
  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:topic) { build(:routing_topic) }
  let(:messages) { [build(:messages_message)] }
  let(:coordinator) { build(:processing_coordinator) }
  let(:consumer) do
    ClassBuilder.inherit(topic.consumer) do
      def consume; end
    end.new
  end

  before { allow(topic.consumer).to receive(:new).and_return(consumer) }

  describe '#id' do
    let(:executor2) { described_class.new(group_id, client, topic) }

    it { expect(executor.id).to be_a(String) }

    it 'expect not to be the same between executors' do
      expect(executor.id).not_to eq(executor2.id)
    end
  end

  describe '#group_id' do
    it { expect(executor.group_id).to eq(group_id) }
  end

  describe '#before_enqueue' do
    before { allow(consumer).to receive(:on_before_enqueue) }

    it do
      expect { executor.before_enqueue(messages, coordinator) }.not_to raise_error
    end

    it 'expect to build appropriate messages batch' do
      executor.before_enqueue(messages, coordinator)
      expect(consumer.messages.first.raw_payload).to eq(messages.first.raw_payload)
    end

    it 'expect to assign appropriate coordinator' do
      executor.before_enqueue(messages, coordinator)
      expect(consumer.coordinator).to eq(coordinator)
    end

    it 'expect to build metadata with proper details' do
      executor.before_enqueue(messages, coordinator)
      expect(consumer.messages.metadata.topic).to eq(topic.name)
    end

    it 'expect to run consumer on_before_enqueue' do
      executor.before_enqueue(messages, coordinator)
      expect(consumer).to have_received(:on_before_enqueue).with(no_args)
    end
  end

  describe '#before_consume' do
    before do
      allow(consumer).to receive(:on_before_consume)
      executor.before_consume
    end

    it 'expect to run consumer#on_before_consume' do
      expect(consumer).to have_received(:on_before_consume).with(no_args)
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

  describe '#after_consume' do
    before do
      allow(consumer).to receive(:on_consume)
      allow(consumer).to receive(:on_after_consume)
      executor.consume
      executor.after_consume
    end

    it 'expect to run consumer' do
      expect(consumer).to have_received(:on_after_consume).with(no_args)
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
