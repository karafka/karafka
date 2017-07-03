# frozen_string_literal: true

RSpec.describe Karafka::Routing::Mapper do
  subject(:mapper) { described_class }

  let(:topic) { rand.to_s }

  describe '#incoming' do
    it { expect(mapper.incoming(topic)).to eq topic }
  end

  describe '#outgoing' do
    it { expect(mapper.outgoing(topic)).to eq topic }
  end
end
