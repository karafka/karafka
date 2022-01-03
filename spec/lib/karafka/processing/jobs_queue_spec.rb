# frozen_string_literal: true

RSpec.describe_current do
  subject(:queue) { described_class.new }

  let(:job1) { OpenStruct.new(group_id: 1, id: 1, call: true) }
  let(:job2) { OpenStruct.new(group_id: 2, id: 1, call: true) }
  let(:internal_queue) { ::Queue.new }

  before { queue.instance_variable_set('@queue', internal_queue) }

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
    before do
      queue << job1
      queue << job2
    end

    context 'when there is a job in the queue and we mark it as completed' do
      it { expect { queue.complete(job1) }.to change(queue, :size).from(2).to(1) }
    end
  end

  describe '#clear' do
    before do
      queue << job1
      queue << job2
    end

    it 'expect to clear a given group only' do
      expect { queue.clear(job1.group_id) }.to change(queue, :size).from(2).to(1)
    end
  end

  describe '#close' do
    context 'when queues are closed already' do
      before { internal_queue.close }

      it { expect { queue.close }.not_to raise_error }

      it 'expect not to close internal queue again' do
        allow(internal_queue).to receive(:close)
        queue.close
        expect(internal_queue).not_to have_received(:close)
      end
    end

    context 'when queue is not yet closed' do
      it { expect { queue.close }.not_to raise_error }

      it 'expect close internal queue' do
        allow(internal_queue).to receive(:close)
        queue.close
        expect(internal_queue).to have_received(:close)
      end
    end
  end

  # Each of those specs would hang forever if something would be wrong, that's why we can easily
  # just run and see if finished. No need for assertions.
  describe '#wait' do
    context 'when we do not have to wait' do
      it 'expect not to pass on the thread execution' do
        queue.wait(job1.group_id)
      end
    end

    context 'when we have to wait' do
      before { queue << job1 }

      it 'expect to pass until no longer needing to wait' do
        Thread.new do
          # We need to close it in order to unlock
          sleep(0.01)
          queue.close
        end

        queue.wait(job1.group_id)
      end
    end

    context 'when Karafka is stopping and the queue is empty' do
      before { allow(Karafka::App).to receive(:stopping?).and_return(true) }

      it 'expect not to wait' do
        queue.wait(job1.group_id)
      end
    end

    context 'when Karafka is stopping and the queue is not empty' do
      before do
        allow(Karafka::App).to receive(:stopping?).and_return(true)
        queue << job1
      end

      it 'expect to wait' do
        Thread.new do
          # We need to close it in order to unlock
          sleep(0.01)
          queue.close
        end

        queue.wait(job1.group_id)
      end
    end

    context 'when queue is closed' do
      before { queue.close }

      it 'expect not to wait' do
        queue.wait(job1.group_id)
      end
    end

    context 'when there are no jobs of a given group' do
      let(:group_id) { SecureRandom.uuid }

      it 'expect not to wait' do
        queue.wait(group_id)
      end
    end
  end

  describe '#size' do
    context 'when there are no jobs' do
      it { expect(queue.size).to eq(0) }
    end

    context 'when there are jobs from one group' do
      let(:job1) { OpenStruct.new(group_id: 1, id: 1, call: true) }
      let(:job2) { OpenStruct.new(group_id: 1, id: 2, call: true) }

      before do
        queue << job1
        queue << job2
      end

      it { expect(queue.size).to eq(2) }
    end

    context 'when there are jobs from multiple groups' do
      before do
        queue << job1
        queue << job2
      end

      it { expect(queue.size).to eq(2) }
    end
  end
end
