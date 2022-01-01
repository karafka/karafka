# frozen_string_literal: true

require 'karafka/pro/active_job/job_options_contract'

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      dispatch_method: :produce_sync
    }
  end

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when there is no dispath method' do
    before { config.delete(:dispatch_method) }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when dispatch method is not valid' do
    before { config[:dispatch_method] = rand.to_s }

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
end
