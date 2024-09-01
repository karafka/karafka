# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      scheduled_messages: {
        consumer_class: consumer_class,
        interval: 5_000,
        flush_batch_size: 10,
        dispatcher_class: Class.new,
        group_id: 'valid_group_id',
        states_postfix: '_states',
        deserializers: {
          headers: Class.new,
          payload: Class.new
        }
      }
    }
  end

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:scheduled_messages) { config[:scheduled_messages] }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when consumer_class is not a subclass of Karafka::BaseConsumer' do
    before { scheduled_messages[:consumer_class] = Class.new }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when group_id does not match the required format' do
    before { scheduled_messages[:group_id] = 'invalid group id' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when interval is less than 1000 milliseconds' do
    before { scheduled_messages[:interval] = 999 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when interval is not an integer' do
    before { scheduled_messages[:interval] = 'not an integer' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when flush_batch_size is not a positive integer' do
    before { scheduled_messages[:flush_batch_size] = 0 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when flush_batch_size is not an integer' do
    before { scheduled_messages[:flush_batch_size] = 'not an integer' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when dispatcher_class is nil' do
    before { scheduled_messages[:dispatcher_class] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when headers deserializer is nil' do
    before { scheduled_messages[:deserializers][:headers] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when payload deserializer is nil' do
    before { scheduled_messages[:deserializers][:payload] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when states postfix is nil' do
    before { scheduled_messages[:states_postfix] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end
end
