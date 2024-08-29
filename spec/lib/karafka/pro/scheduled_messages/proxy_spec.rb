# frozen_string_literal: true

RSpec.describe_current do
  subject(:proxy) { described_class.call(message: message, epoch: epoch, envelope: envelope) }

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

  context 'when message is not valid' do
    before { message.delete(:topic) }

    it { expect { proxy }.to raise_error(WaterDrop::Errors::MessageInvalidError) }
  end

  context 'when message is valid but envelope lacks' do
    let(:envelope) { {} }

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
