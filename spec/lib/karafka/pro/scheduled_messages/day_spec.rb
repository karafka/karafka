# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:day) { described_class.new }

  describe '#created_at' do
    it 'returns the UTC timestamp when the day object was created' do
      expect(day.created_at).to be_within(1).of(Time.now.to_i)
    end
  end

  describe '#ends_at' do
    it 'returns the UTC timestamp of the last second of the day' do
      time = Time.at(day.created_at)
      expected_end_time = Time.utc(time.year, time.month, time.day).to_i + 86_399
      expect(day.ends_at).to eq(expected_end_time)
    end
  end

  describe '#ended?' do
    context 'when the current time is before the end of the day' do
      it 'returns false' do
        allow(Time).to receive(:now).and_return(Time.at(day.ends_at - 1))
        expect(day.ended?).to be(false)
      end
    end

    context 'when the current time is after the end of the day' do
      it 'returns true' do
        allow(Time).to receive(:now).and_return(Time.at(day.ends_at + 1))
        expect(day.ended?).to be(true)
      end
    end
  end
end
