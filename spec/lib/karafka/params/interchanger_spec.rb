require 'spec_helper'

RSpec.describe Karafka::Params::Interchanger do
  subject { described_class }

  let(:params) { double }

  describe '#load' do
    it 'expect to return what was provided' do
      expect(subject.load(params)).to eq params
    end
  end

  describe '#parse' do
    it 'expect to return what was provided' do
      expect(subject.parse(params)).to eq params
    end
  end
end
