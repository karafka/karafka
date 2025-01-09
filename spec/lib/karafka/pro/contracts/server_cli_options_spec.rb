# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:subscription_groups) { { 1 => 1 } }
  let(:config) do
    {
      include_consumer_groups: [],
      include_subscription_groups: [],
      include_topics: [],
      exclude_consumer_groups: [],
      exclude_subscription_groups: [],
      exclude_topics: []
    }
  end

  before { allow(Karafka::App).to receive(:subscription_groups).and_return(subscription_groups) }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when we want to use consumer groups that are not defined' do
    before { config[:include_consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when we want to exclude consumer groups that are not defined' do
    before { config[:exclude_consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when we want to use topics that are not defined' do
    before { config[:include_topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }

    context 'when we have pattern matching defined' do
      before do
        Karafka::App.consumer_groups.pattern(/test/) do
          consumer Class.new
        end
      end

      it { expect(contract.call(config)).to be_success }
    end
  end

  context 'when we want to exclude topics that are not defined' do
    before { config[:exclude_topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }

    context 'when we have pattern matching defined' do
      before do
        Karafka::App.consumer_groups.pattern(/test/) do
          consumer Class.new
        end
      end

      it { expect(contract.call(config)).to be_success }
    end
  end

  context 'when we want to use subscription groups that are not defined' do
    before { config[:include_subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when we want to exclude subscription groups that are not defined' do
    before { config[:exclude_subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when nothing to listen on' do
    let(:subscription_groups) { {} }

    it { expect(contract.call(config)).not_to be_success }
  end
end
