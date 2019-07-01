# frozen_string_literal: true

RSpec.describe Karafka::Contracts::ServerCliOptions do
  subject(:contract) { described_class.new }

  let(:config) { { pid: 'name' } }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when we want to use consumer groups that are not defined' do
    before { config[:consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when we want to use pidfile that already exists' do
    before { config[:pid] = Tempfile.new.path }

    it { expect(contract.call(config)).not_to be_success }
  end
end
