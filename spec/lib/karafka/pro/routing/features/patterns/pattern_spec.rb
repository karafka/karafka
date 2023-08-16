# frozen_string_literal: true

RSpec.describe_current do
  subject(:pattern) { described_class.new(regexp, config) }

  let(:regexp) { /test_/ }
  let(:config) { proc { 'some_configuration' } }

  describe '#initialize' do
    it 'expect to assign the provided regexp' do
      expect(pattern.regexp).to eq(regexp)
    end

    it 'expect to generate a topic_name' do
      expect(pattern.topic_name).to start_with('karafka-pattern-')
    end

    it 'expect to generate a unique topic_name each time' do
      another_pattern = described_class.new(regexp, config)
      expect(pattern.topic_name).not_to eq(another_pattern.topic_name)
    end
  end

  describe '#to_h' do
    it 'expect to return a hash representation of the pattern' do
      expect(pattern.to_h).to eq(
        {
          regexp: regexp,
          topic_name: pattern.topic_name
        }
      )
    end

    it 'expect to return a frozen hash' do
      expect(pattern.to_h).to be_frozen
    end
  end
end
