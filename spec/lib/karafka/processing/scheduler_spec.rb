# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new(queue) }

  let(:queue) { [] }
  let(:jobs_array) { [] }

  describe '#schedule_consumption' do
    subject(:schedule) { scheduler.schedule_consumption(jobs_array) }

    context 'when there are no messages' do
      it 'expect not to schedule anything' do
        schedule
        expect(queue).to be_empty
      end
    end

    context 'when there are jobs' do
      let(:jobs_array) do
        [
          Karafka::Processing::Jobs::Consume.new(nil, []),
          Karafka::Processing::Jobs::Consume.new(nil, []),
          Karafka::Processing::Jobs::Consume.new(nil, []),
          Karafka::Processing::Jobs::Consume.new(nil, [])
        ]
      end

      it 'expect to schedule in the fifo order' do
        schedule
        expect(queue).to eq(jobs_array)
      end
    end
  end

  describe '#manage' do
    it { expect { scheduler.manage }.not_to raise_error }
  end

  describe '#clear' do
    it { expect { scheduler.clear(rand.to_s) }.not_to raise_error }
  end
end
