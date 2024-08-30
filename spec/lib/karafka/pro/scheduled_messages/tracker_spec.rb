# frozen_string_literal: true

RSpec.describe_current do
  let(:tracker) { described_class.new }
  let(:current_time) { Time.now.to_i }
  let(:today_date) { Time.at(current_time).utc.to_date.to_s }

  before do
    # Stubbing Time.now to have consistent test results
    allow(Time).to receive(:now).and_return(Time.at(current_time))
  end

  describe '#initialize' do
    it 'initializes with an empty daily hash and current time' do
      expect(tracker.daily).to eq({})
      expect(tracker.state).to be_nil
    end
  end

  describe '#today=' do
    it 'sets the count for the current day' do
      tracker.today = 5
      expect(tracker.daily[today_date]).to eq(5)
    end
  end

  describe '#track' do
    let(:message) do
      instance_double(
        'Karafka::Messages::Message',
        headers: { 'schedule_target_epoch' => epoch }
      )
    end

    context 'when tracking a message for today' do
      let(:epoch) { current_time }

      it 'increases the count for the current day' do
        tracker.today = 5
        tracker.track(message)
        expect(tracker.daily[today_date]).to eq(6)
      end
    end

    context 'when tracking a message for a future day' do
      let(:future_time) { Time.now.to_i + 86_400 } # One day in the future
      let(:future_date) { Time.at(future_time).utc.to_date.to_s }
      let(:epoch) { future_time }

      it 'increases the count for the future day' do
        tracker.track(message)
        expect(tracker.daily[future_date]).to eq(1)
      end
    end

    context 'when tracking a message for a past day' do
      let(:past_time) { Time.now.to_i - 86_400 } # One day in the past
      let(:past_date) { Time.at(past_time).utc.to_date.to_s }
      let(:epoch) { past_time }

      it 'increases the count for the past day' do
        tracker.track(message)
        expect(tracker.daily[past_date]).to eq(1)
      end
    end
  end

  describe '#epoch_to_date' do
    it 'converts an epoch to the correct date string' do
      epoch = Time.now.to_i
      date_string = Time.at(epoch).utc.to_date.to_s
      expect(tracker.send(:epoch_to_date, epoch)).to eq(date_string)
    end
  end
end
