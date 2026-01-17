# frozen_string_literal: true

RSpec.describe_current do
  subject(:base) { described_class.new }

  describe '#initialize' do
    it 'freezes the instance for Ractor shareability' do
      expect(base).to be_frozen
    end
  end
end
