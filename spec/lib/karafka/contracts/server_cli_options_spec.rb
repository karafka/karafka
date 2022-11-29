# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) { {} }
  let(:subscription_groups) { { 1 => 1 } }

  before { allow(Karafka::App).to receive(:subscription_groups).and_return(subscription_groups) }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when we want to use consumer groups that are not defined' do
    before { config[:consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when we want to use topics that are not defined' do
    before { config[:topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when we want to use subscription groups that are not defined' do
    before { config[:subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when nothing to listen on' do
    let(:subscription_groups) { {} }

    it { expect(contract.call(config)).not_to be_success }
  end
end
