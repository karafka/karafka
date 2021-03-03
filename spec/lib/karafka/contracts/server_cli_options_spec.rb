# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) { {} }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when we want to use consumer groups that are not defined' do
    before { config[:consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end
end
