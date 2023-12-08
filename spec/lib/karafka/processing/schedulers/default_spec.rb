# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new(queue) }

  let(:queue) { [] }
  let(:jobs_array) { [] }

  %i[
    on_schedule_consumption
    on_schedule_revocation
    on_schedule_shutdown
    on_schedule_idle
  ].each do |action|
    describe "##{action}" do
      subject(:schedule) { scheduler.public_send(action, jobs_array) }

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
  end

  describe '#manage' do
    it { expect { scheduler.on_manage }.not_to raise_error }
  end

  describe '#clear' do
    it { expect { scheduler.on_clear(rand.to_s) }.not_to raise_error }
  end
end
