# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:message) do
    {
      key: 'message_key',
      headers: {
        'schedule_schema_version' => '1.0',
        'schedule_target_epoch' => (Time.now.to_i + 60).to_s,
        'schedule_source_type' => 'type',
        'schedule_target_topic' => 'valid_topic'
      }
    }
  end

  context 'when message is valid' do
    it { expect(contract.call(message)).to be_success }
  end

  context 'when key is empty' do
    before { message[:key] = '' }

    it { expect(contract.call(message)).not_to be_success }
  end

  context 'when key is not a string' do
    before { message[:key] = 12_345 }

    it { expect(contract.call(message)).not_to be_success }
  end

  context 'when headers do not include all expected keys' do
    before { message[:headers].delete('schedule_schema_version') }

    it { expect(contract.call(message)).not_to be_success }
  end

  context 'when headers is not a hash' do
    before { message[:headers] = 'not a hash' }

    it { expect(contract.call(message)).not_to be_success }
  end

  context 'when schedule_target_epoch is in the past' do
    before { message[:headers]['schedule_target_epoch'] = (Time.now.to_i - 20).to_s }

    it { expect(contract.call(message)).not_to be_success }
  end

  context 'when schedule_target_epoch is exactly 10 seconds in the past' do
    before { message[:headers]['schedule_target_epoch'] = (Time.now.to_i - 10).to_s }

    it { expect(contract.call(message)).to be_success }
  end

  context 'when schedule_target_epoch is within the allowed grace period' do
    before { message[:headers]['schedule_target_epoch'] = (Time.now.to_i - 5).to_s }

    it { expect(contract.call(message)).to be_success }
  end

  context 'when schedule_target_epoch is in the future' do
    before { message[:headers]['schedule_target_epoch'] = (Time.now.to_i + 60).to_s }

    it { expect(contract.call(message)).to be_success }
  end
end
