require 'spec_helper'

RSpec.describe Dry::Configurable::Config do
  let(:keys) { %i( a b ) }
  subject { described_class.new(*keys).new(*values) }

  describe 'non proc example' do
    let(:values) { [rand, rand] }

    it 'expect to store and return values' do
      keys.each_with_index do |key, index|
        expect(subject.public_send(key)).to eq values[index]
      end
    end
  end

  describe 'proc values' do
    let(:values) { [-> { 1 }, -> { 2 }] }

    it 'expect to store and return values' do
      keys.each_with_index do |key, index|
        expect(subject.public_send(key)).to eq values[index].call
      end
    end
  end
end
