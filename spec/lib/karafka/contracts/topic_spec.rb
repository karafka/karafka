# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      id: 'id',
      name: 'name',
      consumer: Class.new,
      deserializer: Class.new,
      kafka: { 'bootstrap.servers' => 'localhost:9092' },
      max_messages: 10,
      max_wait_time: 10_000,
      initial_offset: 'earliest',
      subscription_group: SecureRandom.uuid
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when we validate id' do
    context 'when it is nil' do
      before { config[:id] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:id] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when it is an invalid string' do
      before { config[:id] = '%^&*(' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate name' do
    context 'when it is nil' do
      before { config[:name] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:name] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when it is an invalid string' do
      before { config[:name] = '%^&*(' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we subscription_group' do
    context 'when it is nil' do
      before { config[:subscription_group] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:subscription_group] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when it is an empty string' do
      before { config[:subscription_group] = '' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate consumer' do
    context 'when it is not present' do
      before { config[:consumer] = nil }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate deserializer' do
    context 'when it is not present' do
      before { config[:deserializer] = nil }

      it { expect(check).not_to be_success }
    end
  end

  context 'when kafka contains errors from rdkafka' do
    before { config[:kafka] = { 'message.max.bytes' => 0 } }

    it { expect(check).not_to be_success }
  end

  context 'when we validate initial_offset' do
    context 'when it is not present' do
      before { config[:initial_offset] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when earliest' do
      before { config[:initial_offset] = 'earliest' }

      it { expect(check).to be_success }
    end

    context 'when latest' do
      before { config[:initial_offset] = 'latest' }

      it { expect(check).to be_success }
    end

    context 'when not supported' do
      before { config[:initial_offset] = rand.to_s }

      it { expect(check).not_to be_success }
    end
  end
end
