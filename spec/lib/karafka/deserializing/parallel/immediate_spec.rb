# frozen_string_literal: true

RSpec.describe_current do
  subject(:immediate) { described_class.instance }

  describe '.instance' do
    it 'returns a singleton instance' do
      instance1 = described_class.instance
      instance2 = described_class.instance
      expect(instance1).to be(instance2)
    end
  end

  describe '#retrieve' do
    it 'does nothing and returns nil' do
      expect(immediate.retrieve).to be_nil
    end

    it 'can be called multiple times safely' do
      expect { 3.times { immediate.retrieve } }.not_to raise_error
    end
  end
end
