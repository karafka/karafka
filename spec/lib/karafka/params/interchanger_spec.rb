# frozen_string_literal: true

RSpec.describe Karafka::Params::Interchanger do
  subject(:interchanger_class) { described_class }

  let(:params) { double }

  describe '#load' do
    it 'expect to return what was provided' do
      expect(interchanger_class.load(params)).to eq params
    end
  end

  describe '#parse' do
    it 'expect to return what was provided' do
      expect(interchanger_class.parse(params)).to eq params
    end
  end
end
