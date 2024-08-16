# frozen_string_literal: true

RSpec.describe_current do
  subject(:cron) { described_class.new(expression) }

  let(:last_timestamp) { Time.utc(2023, 1, 1, 0, 0, 0) }

  context 'when expression is not valid' do
    let(:expression) { '* *' }
    let(:expected_error) { Karafka::Pro::RecurringTasks::Errors::InvalidCronExpressionError }

    it { expect { cron }.to raise_error(expected_error) }
  end

  context 'when expression has too many fields' do
    let(:expression) { '* * * * * *' }
    let(:expected_error) { Karafka::Pro::RecurringTasks::Errors::InvalidCronExpressionError }

    it { expect { cron }.to raise_error(expected_error) }
  end

  context 'when expression is valid' do
    let(:expression) { '* * * * *' }

    it { expect { cron }.not_to raise_error }
  end

  context 'when expression uses step values' do
    let(:expression) { '*/15 0 * * *' }

    it { expect { cron }.not_to raise_error }
  end

  describe '#next_time' do
    context 'when expression is "*/5 * * * *"' do
      let(:expression) { '*/5 * * * *' }

      it 'returns the next timestamp exactly 5 minutes later' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(last_timestamp + 300) # 300 seconds = 5 minutes
      end

      context 'when last timestamp is close to the hour' do
        let(:last_timestamp) { Time.utc(2023, 1, 1, 0, 55, 0) }

        it 'returns the next timestamp at the top of the hour' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 1, 1, 1, 0, 0))
        end
      end
    end

    context 'when expression is "0 * * * *"' do
      let(:expression) { '0 * * * *' }

      it 'returns the next timestamp at the top of the next hour' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(last_timestamp + 3600) # 3600 seconds = 1 hour
      end

      context 'when the last timestamp is close to midnight' do
        let(:last_timestamp) { Time.utc(2023, 1, 1, 23, 59, 0) }

        it 'returns the next timestamp at the start of the next day' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 1, 2, 0, 0, 0))
        end
      end
    end

    context 'when expression is "15 14 1 * *"' do
      let(:expression) { '15 14 1 * *' }

      it 'returns the correct next timestamp on the 1st of the month at 14:15' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2023, 1, 1, 14, 15, 0))
      end

      context 'when the last timestamp is after the specified time on the 1st' do
        let(:last_timestamp) { Time.utc(2023, 2, 1, 14, 16, 0) }

        it 'returns the next timestamp on the 1st of the next month' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 3, 1, 14, 15, 0))
        end
      end
    end

    context 'when expression is "0 22 * * 1-5"' do
      let(:expression) { '0 22 * * 1-5' }

      it 'returns the next timestamp at 22:00 on a weekday' do
        last_timestamp = Time.utc(2023, 1, 2, 21, 0, 0) # A Monday
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2023, 1, 2, 22, 0, 0))
      end

      context 'when the last timestamp is on a Friday night' do
        let(:last_timestamp) { Time.utc(2023, 1, 6, 23, 0, 0) } # A Friday

        it 'returns the next timestamp on the following Monday at 22:00' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 1, 9, 22, 0, 0))
        end
      end
    end

    context 'when expression is "0 22 * * 6,0"' do
      let(:expression) { '0 22 * * 6,0' } # Saturday and Sunday

      it 'returns the next timestamp at 22:00 on the next Saturday or Sunday' do
        last_timestamp = Time.utc(2023, 1, 1, 21, 0, 0) # A Sunday
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2023, 1, 1, 22, 0, 0))
      end

      context 'when the last timestamp is on a Saturday morning' do
        let(:last_timestamp) { Time.utc(2023, 1, 7, 9, 0, 0) } # A Saturday

        it 'returns the next timestamp on the same day at 22:00' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 1, 7, 22, 0, 0))
        end
      end
    end

    context 'when expression is "59 23 31 12 *"' do
      let(:expression) { '59 23 31 12 *' }

      it 'returns the next timestamp on December 31st at 23:59' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2023, 12, 31, 23, 59, 0))
      end

      context 'when the last timestamp is already on December 31st at 23:59' do
        let(:last_timestamp) { Time.utc(2023, 12, 31, 23, 59, 0) }

        it 'returns the next timestamp on December 31st of the following year' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2024, 12, 31, 23, 59, 0))
        end
      end
    end

    context 'when expression is "0 0 1 1 *"' do
      let(:expression) { '0 0 1 1 *' }

      it 'returns the next timestamp on January 1st at 00:00' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2024, 1, 1, 0, 0, 0))
      end
    end

    context 'when expression is "30 8 1,15 * *"' do
      let(:expression) { '30 8 1,15 * *' }

      it 'returns the next timestamp on the 1st or 15th at 08:30' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2023, 1, 1, 8, 30, 0))
      end

      context 'when the last timestamp is after the 1st at 08:30' do
        let(:last_timestamp) { Time.utc(2023, 1, 1, 8, 31, 0) }

        it 'returns the next timestamp on the 15th at 08:30' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 1, 15, 8, 30, 0))
        end
      end
    end

    context 'when expression is "0 0 * * 1"' do
      let(:expression) { '0 0 * * 1' } # Every Monday at midnight

      it 'returns the next timestamp on the following Monday at 00:00' do
        next_timestamp = cron.next_time(last_timestamp)
        expect(next_timestamp).to eq(Time.utc(2023, 1, 2, 0, 0, 0)) # Monday
      end

      context 'when the last timestamp is already on a Monday at midnight' do
        let(:last_timestamp) { Time.utc(2023, 1, 2, 0, 0, 0) }

        it 'returns the next timestamp on the following Monday at 00:00' do
          next_timestamp = cron.next_time(last_timestamp)
          expect(next_timestamp).to eq(Time.utc(2023, 1, 9, 0, 0, 0)) # Next Monday
        end
      end
    end
  end
end
