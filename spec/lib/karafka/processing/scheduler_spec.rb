# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new }

  describe '#schedule_consumption' do
    subject(:schedule) { scheduler.schedule_consumption(queue, jobs_array) }

    let(:queue) { [] }
    let(:jobs_array) { [] }

    context 'when there are no messages' do
      it 'expect not to schedule anything' do
        schedule
        expect(queue).to be_empty
      end
    end

    context 'when there are jobs' do
      let(:jobs_array) do
        [
          Karafka::Processing::Jobs::Consume.new(nil, [], nil),
          Karafka::Processing::Jobs::Consume.new(nil, [], nil),
          Karafka::Processing::Jobs::Consume.new(nil, [], nil),
          Karafka::Processing::Jobs::Consume.new(nil, [], nil)
        ]
      end

      it 'expect to schedule in the fifo order' do
        schedule
        expect(queue).to eq(jobs_array)
      end
    end
  end
end
