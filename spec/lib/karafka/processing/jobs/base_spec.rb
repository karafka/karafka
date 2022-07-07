# frozen_string_literal: true

RSpec.describe_current do
  describe '#non_blocking?' do
    it 'expect all the newly created jobs to be blocking' do
      expect(described_class.new.non_blocking?).to eq(false)
    end
  end

  describe '#call' do
    it { expect { described_class.new.call }.to raise_error(NotImplementedError) }
  end
end
