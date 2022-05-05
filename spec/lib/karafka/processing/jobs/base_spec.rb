# frozen_string_literal: true

RSpec.describe_current do
  describe '#non_blocking?' do
    it 'expect all the newly created jobs to be blocking' do
      expect(described_class.new.non_blocking?).to eq(false)
    end

    it 'expect job that is marked as unblocked not to be blocking' do
      job = described_class.new
      job.unblock!
      expect(job.non_blocking?).to eq(true)
    end
  end
end
