# frozen_string_literal: true

RSpec.describe_current do
  let(:tracker) do
    instance_double(
      Karafka::Pro::ScheduledMessages::Tracker,
      state: { key: 'value' },
      daily: { daily_key: 'daily_value' }
    )
  end

  let(:serializer) { described_class.new }
  let(:float_now) { rand }

  before { allow(serializer).to receive(:float_now).and_return(float_now) }

  describe '#state' do
    it 'serializes and compresses the state data' do
      expected_data = {
        schema_version: Karafka::Pro::ScheduledMessages::STATES_SCHEMA_VERSION,
        dispatched_at: float_now,
        state: tracker.state,
        daily: tracker.daily
      }.to_json

      compressed_data = Zlib::Deflate.deflate(expected_data)

      expect(serializer.state(tracker)).to eq(compressed_data)
    end

    context 'when tracker has no state or daily data' do
      let(:tracker) do
        instance_double(
          Karafka::Pro::ScheduledMessages::Tracker,
          state: nil,
          daily: nil
        )
      end

      it 'still serializes and compresses the data correctly' do
        expected_data = {
          schema_version: Karafka::Pro::ScheduledMessages::STATES_SCHEMA_VERSION,
          dispatched_at: float_now,
          state: nil,
          daily: nil
        }.to_json

        compressed_data = Zlib::Deflate.deflate(expected_data)

        expect(serializer.state(tracker)).to eq(compressed_data)
      end
    end
  end
end
