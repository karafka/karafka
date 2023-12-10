# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new(queue) }

  let(:queue) { [] }
  let(:jobs_array) { [] }

  describe '#on_schedule_consumption' do
    it { expect { scheduler.on_schedule_consumption([]) }.to raise_error(NotImplementedError) }
  end

  describe '#schedule_consumption' do
    it { expect { scheduler.schedule_consumption([]) }.to raise_error(NotImplementedError) }
  end

  %i[
    on_schedule_revocation
    on_schedule_shutdown
    on_schedule_periodic
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

  describe '#on_manage' do
    it { expect { scheduler.on_manage }.not_to raise_error }
  end

  describe '#manage' do
    it { expect { scheduler.manage }.not_to raise_error }
  end

  describe '#on_clear' do
    it { expect { scheduler.on_clear(1) }.not_to raise_error }
  end

  describe '#clear' do
    it { expect { scheduler.clear(1) }.not_to raise_error }
  end
end
