require 'spec_helper'

RSpec.describe Karafka::Params do
  describe '#parse' do
    let(:options) { { a: '1' } }
    it 'returns hashWithIndifferentAccess for JSON' do
      hash = described_class.new(options.to_json).parse
      expect(hash[:a]).to eq(hash['a'])
    end

    it 'returns string for String' do
      hash = described_class.new(options.to_s).parse
      expect(hash).to eq({ a: '1' }.to_s)
    end
  end
end
