# frozen_string_literal: true

RSpec.describe_current do
  subject(:pattern) { described_class.new(name, regexp, config) }

  let(:name) { nil }
  let(:regexp) { /test_/ }
  let(:config) { proc { 'some_configuration' } }

  describe '#initialize' do
    it 'expect to assign the provided regexp' do
      expect(pattern.regexp).to eq(regexp)
    end

    it 'expect to generate a name' do
      expect(pattern.name).to start_with('karafka-pattern-')
    end

    it 'expect to generate a unique name each time for different regexp' do
      another_pattern = described_class.new(nil, /test/, config)
      expect(pattern.name).not_to eq(another_pattern.name)
    end

    context 'when initialized with a selected name' do
      let(:name) { SecureRandom.uuid }

      it 'expect to use it and not to generate one' do
        expect(pattern.name).to eq(name)
      end
    end
  end

  describe '#to_h' do
    it 'expect to return a hash representation of the pattern' do
      expect(pattern.to_h).to eq(
        {
          regexp: regexp,
          name: pattern.name,
          regexp_string: '^test_'
        }
      )
    end

    it 'expect to return a frozen hash' do
      expect(pattern.to_h).to be_frozen
    end
  end
end
