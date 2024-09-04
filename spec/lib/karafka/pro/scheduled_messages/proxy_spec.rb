# frozen_string_literal: true

RSpec.describe_current do
  describe '.schedule' do
    subject(:proxy) do
      described_class.schedule(message: message, epoch: epoch, envelope: envelope)
    end

    let(:epoch) { Time.now.to_i }

    let(:envelope) do
      {
        topic: 'proxy_topic',
        key: 'unique-key'
      }
    end

    let(:message) do
      {
        topic: 'target_topic',
        partition: 2,
        key: 'test-key',
        partition_key: 'pk',
        payload: 'payload',
        headers: {
          'special' => 'header'
        }
      }
    end

    before do
      Karafka::App.config.internal.routing.builder.draw do
        scheduled_messages(:proxy_topic)
      end
    end

    context 'when message is not valid' do
      before { message.delete(:topic) }

      it { expect { proxy }.to raise_error(WaterDrop::Errors::MessageInvalidError) }
    end

    context 'when message is valid but envelope lacks' do
      let(:envelope) { { topic: 'proxy_topic', partition: nil } }

      it { expect { proxy }.to raise_error(WaterDrop::Errors::MessageInvalidError) }
    end

    context 'when all valid' do
      it { expect(proxy[:topic]).to eq('proxy_topic') }
      it { expect(proxy[:payload]).to eq('payload') }
      it { expect(proxy[:key]).to eq('unique-key') }
      it { expect(proxy[:headers]['special']).to eq('header') }
      it { expect(proxy[:headers]['schedule_schema_version']).to eq('1.0.0') }
      it { expect(proxy[:headers]['schedule_target_epoch']).to eq(epoch.to_s) }
      it { expect(proxy[:headers]['schedule_source_type']).to eq('schedule') }
      it { expect(proxy[:headers]['schedule_target_topic']).to eq('target_topic') }
      it { expect(proxy[:headers]['schedule_target_partition']).to eq('2') }
      it { expect(proxy[:headers]['schedule_target_key']).to eq('test-key') }
      it { expect(proxy[:headers]['schedule_target_partition_key']).to eq('pk') }
    end

    context 'when envelope key is missing' do
      let(:uuid) { SecureRandom.uuid }

      before do
        envelope.delete(:key)
        allow(SecureRandom).to receive(:uuid).and_return(uuid)
      end

      it 'expect to build a dynamic one' do
        expect(proxy[:key]).to include("target_topic-#{uuid}")
      end
    end

    context 'when trying to dispatch in past' do
      let(:epoch) { Time.now.to_i - 100 }

      it { expect { proxy }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
    end
  end

  describe '.cancel' do
    let(:key) { 'unique-key' }
    let(:envelope) do
      {
        topic: 'cancel_topic',
        partition: 1
      }
    end

    subject(:cancel_message) { described_class.cancel(key: key, envelope: envelope) }

    it 'creates a message with the correct headers' do
      version = Karafka::Pro::ScheduledMessages::SCHEMA_VERSION
      expect(cancel_message[:headers]['schedule_source_type']).to eq('cancel')
      expect(cancel_message[:headers]['schedule_schema_version']).to eq(version)
    end

    it 'includes the correct key' do
      expect(cancel_message[:key]).to eq(key)
    end

    it 'has a nil payload' do
      expect(cancel_message[:payload]).to be_nil
    end
  end

  describe '.tombstone' do
    let(:message) do
      instance_double(
        'Karafka::Messages::Message',
        key: 'unique-key',
        topic: 'tombstone_topic',
        partition: 2,
        offset: 123,
        raw_headers: {
          'existing-header' => 'value'
        }
      )
    end

    subject(:tombstone_message) { described_class.tombstone(message: message) }

    it 'creates a message with the correct headers' do
      version = Karafka::Pro::ScheduledMessages::SCHEMA_VERSION
      expect(tombstone_message[:headers]['schedule_source_type']).to eq('tombstone')
      expect(tombstone_message[:headers]['schedule_schema_version']).to eq(version)
      expect(tombstone_message[:headers]['schedule_source_offset']).to eq('123')
    end

    it 'includes the correct key' do
      expect(tombstone_message[:key]).to eq('unique-key')
    end

    it 'has a nil payload' do
      expect(tombstone_message[:payload]).to be_nil
    end

    it 'includes the correct topic' do
      expect(tombstone_message[:topic]).to eq('tombstone_topic')
    end

    it 'includes the correct partition' do
      expect(tombstone_message[:partition]).to eq(2)
    end

    it 'includes existing headers' do
      expect(tombstone_message[:headers]['existing-header']).to eq('value')
    end
  end
end
