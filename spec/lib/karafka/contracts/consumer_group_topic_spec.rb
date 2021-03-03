# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      id: 'id',
      name: 'name',
      consumer: Class.new,
      deserializer: Class.new,
      manual_offset_management: false,
      kafka: { 'bootstrap.servers' => 'localhost:9092' },
      max_messages: 10,
      max_wait_time: 10_000
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

  context 'when we validate manual_offset_management' do
    context 'when it is not present' do
      before { config.delete(:manual_offset_management) }

      it { expect(check).not_to be_success }
    end

    context 'when it is not boolean' do
      before { config[:manual_offset_management] = nil }

      it { expect(check).not_to be_success }
    end
  end

  context 'when kafka contains errors from rdkafka' do
    before { config[:kafka] = { 'message.max.bytes' => 0 } }

    it { expect(check).not_to be_success }
  end
end
