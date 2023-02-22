# frozen_string_literal: true

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

  context 'when there is no dispath many method' do
    before { config.delete(:dispatch_many_method) }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when dispatch many method is not valid' do
    before { config[:dispatch_many_method] = rand.to_s }

    it { expect(contract.call(config)).not_to be_success }
  end
end
