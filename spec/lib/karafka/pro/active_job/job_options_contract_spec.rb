# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      dispatch_method: :produce_sync,
      partition_key_type: :key,
      producer: nil
    }
  end

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when there is no dispath method' do
    before { config.delete(:dispatch_method) }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when there is no producer' do
    before { config.delete(:producer) }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when producer does not respond to callable' do
    before { config[:producer] = 1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when there is no partition key type' do
    before { config.delete(:partition_key_type) }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when partition key type is :partition itself' do
    before { config[:partition_key_type] = :partition }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when partition key type is something unexpected' do
    before { config[:partition_key_type] = rand.to_s }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when dispatch method is not valid' do
    before { config[:dispatch_method] = rand.to_s }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when there is no dispath many method' do
    before { config.delete(:dispatch_many_method) }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when dispatch many method is not valid' do
    before { config[:dispatch_many_method] = rand.to_s }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when partitioner is not callable' do
    before { config[:partitioner] = 1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when partitioner is a proc' do
    before { config[:partitioner] = -> { '1' } }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when partitioner is a callable instance' do
    let(:callable) { klass.new }

    let(:klass) do
      Class.new do
        def call(job)
          job.job_id
        end
      end
    end

    before { config[:partitioner] = callable }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when scheduled_messages_topic is present but invalid' do
    before { config[:scheduled_messages_topic] = '$%^&*()' }

    it { expect(contract.call(config)).not_to be_success }
  end
end
