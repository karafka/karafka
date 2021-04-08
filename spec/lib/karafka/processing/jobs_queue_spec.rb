# frozen_string_literal: true

RSpec.describe_current do
  subject(:queue) { described_class.new }

  let(:job1) { OpenStruct.new(group_id: 1, id: 1, call: true) }
  let(:job2) { OpenStruct.new(group_id: 2, id: 1, call: true) }

  describe '#<<' do
    context 'when queue is closed' do
      before do
        queue.close
        queue << job1
      end

      it { expect(queue.size).to eq(0) }
    end

    context 'when the queue is not closed' do
      before { queue << job1 }

      it { expect(queue.size).to eq(1) }
    end

    context 'when we want to add a job from a group that is in processing' do
      let(:expected_error) { Karafka::Errors::JobsQueueSynchronizationError }

      before { queue << job1 }

      it { expect { queue << job1 }.to raise_error(expected_error) }
    end

    context 'when we want to add a job from a group that is not in processing' do
      before { queue << job1 }

      it { expect { queue << job2 }.not_to raise_error }
      it { expect { queue << job2 }.to change(queue, :size).from(1).to(2) }
    end
  end

  describe '#pop' do
    before { queue << job1 }

    it { expect(queue.pop).to eq(job1) }
    it { expect { queue.pop }.not_to change(queue, :size) }
  end

  describe '#complete' do
    pending
  end

  describe '#clear' do
    pending
  end

  describe '#stop' do
    pending
  end

  describe '#wait' do
    pending
  end

  describe '#size' do
    pending
  end
end
