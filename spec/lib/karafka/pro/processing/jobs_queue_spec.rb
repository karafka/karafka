# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:queue) { described_class.new }

  let(:job1) { job_n.call }
  let(:job2) { job_n.call }
  let(:internal_queue) { ::Queue.new }
  let(:job_n) do
    -> { OpenStruct.new(group_id: 2, id: SecureRandom.uuid, call: true, non_blocking?: false) }
  end

  before do
    allow(Karafka::App.config).to receive(:concurrency).and_return(5)
    queue.instance_variable_set('@queue', internal_queue)
    queue.register(job1.group_id)
    queue.register(job2.group_id)
  end

  describe '#<<' do
    context 'when queue is closed' do
      before do
        queue.close
        queue << job1
      end

      it { expect(queue.statistics).to eq(enqueued: 0, busy: 0, waiting: 0) }
    end

    context 'when the queue is not closed' do
      before { queue << job1 }

      it { expect(queue.statistics).to eq(busy: 1, enqueued: 0, waiting: 0) }
    end

    context 'when we want to add a job from a group that is in processing' do
      let(:expected_error) { Karafka::Errors::JobsQueueSynchronizationError }

      before { queue << job1 }

      it { expect { queue << job1 }.to raise_error(expected_error) }
    end

    context 'when we want to add a job from a group that is not in processing' do
      before { queue << job1 }

      it { expect { queue << job2 }.not_to raise_error }
      it { expect(queue.statistics).to eq(busy: 1, enqueued: 0, waiting: 0) }

      context 'when all workers are busy' do
        before { 10.times { queue << job_n.call } }

        it { expect(queue.statistics).to eq(busy: 5, enqueued: 6, waiting: 0) }
      end
    end
  end

  describe '#pop' do
    before { queue << job1 }

    it { expect(queue.pop).to eq(job1) }
    it { expect(queue.statistics).to eq(busy: 1, enqueued: 0, waiting: 0) }
  end

  describe '#complete' do
    before do
      queue << job1
      queue << job2
    end

    context 'when there is a job in the queue and we mark it as completed' do
      before { queue.complete(queue.pop) }

      it { expect(queue.statistics).to eq(busy: 1, enqueued: 0, waiting: 0) }
    end

    context 'when there are more jobs than concurrency and we complete' do
      before do
        8.times { queue << job_n.call }

        queue.complete(queue.pop)
      end

      it { expect(queue.statistics).to eq(busy: 5, enqueued: 4, waiting: 0) }
    end
  end

  describe '#clear' do
    before do
      queue << job1
      queue << job2
    end

    it 'expect to clear a given group only' do
      expect { queue.clear(job1.group_id) }.not_to change(queue, :statistics)
    end
  end

  describe '#lock' do
    context 'when we lock a job' do
      before { queue.lock(job1) }

      it { expect(queue.statistics).to eq(busy: 0, enqueued: 0, waiting: 1) }

      context 'when we try to lock the same job twice' do
        let(:expected_error) { Karafka::Errors::JobsQueueSynchronizationError }

        it { expect { queue.lock(job1) }.to raise_error(expected_error) }
      end
    end
  end

  describe '#unlock' do
    context 'when we unlock a job' do
      before do
        queue.lock(job1)
        queue.unlock(job1)
      end

      it { expect(queue.statistics).to eq(busy: 0, enqueued: 0, waiting: 0) }

      context 'when we try to unlock the same job twice' do
        let(:expected_error) { Karafka::Errors::JobsQueueSynchronizationError }

        it { expect { queue.unlock(job1) }.to raise_error(expected_error) }
      end
    end
  end

  describe '#lock_async' do
    let(:subscription_group_id) { SecureRandom.uuid }
    let(:id) { SecureRandom.uuid }

    before { queue.register(subscription_group_id) }

    context 'when we lock' do
      before { queue.lock_async(subscription_group_id, id) }

      it { expect(queue.empty?(subscription_group_id)).to be(false) }

      it 'expect not to impact statistics' do
        expect(queue.statistics).to eq(busy: 0, enqueued: 0, waiting: 0)
      end

      context 'when we try to lock the same job twice' do
        it { expect { queue.lock_async(subscription_group_id, id) }.not_to raise_error }
      end
    end

    context 'when we lock with a timeout and it passes' do
      before do
        queue.register(subscription_group_id)
        queue.lock_async(subscription_group_id, id, timeout: 100)
      end

      it 'expect to finish after a timeout tick and wait time' do
        queue.wait(subscription_group_id)
      end
    end
  end

  describe '#unlock_async' do
    context 'when we unlock a group' do
      before do
        queue.register(1)
        queue.lock_async(1, 1)
        queue.unlock_async(1, 1)
      end

      it { expect(queue.statistics).to eq(busy: 0, enqueued: 0, waiting: 0) }

      context 'when we try to unlock the same job twice' do
        let(:expected_error) { Karafka::Errors::JobsQueueSynchronizationError }

        it { expect { queue.unlock_async(1, 1) }.to raise_error(expected_error) }
      end
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

    context 'when we have to wait for a job' do
      let(:thread) do
        Thread.new do
          sleep(0.01)
          queue.complete(job1)
        end
      end

      before do
        thread
        queue << job1
      end

      after { thread.join }

      it 'expect to pass until no longer needing to wait' do
        queue.wait(job1.group_id)
      end
    end

    context 'when we have to wait for an async lock' do
      let(:thread) do
        Thread.new do
          sleep(0.01)
          queue.unlock_async(1, 1)
        end
      end

      before do
        queue.register(1)

        thread
        queue.lock_async(1, 1)
      end

      after { thread.join }

      it 'expect to pass until no longer needing to wait' do
        queue.wait(1)
      end
    end

    context 'when we have to wait and tick runs' do
      let(:thread1) do
        Thread.new do
          sleep(0.1)
          10.times { queue.tick(job1.group_id) }
        end
      end

      let(:thread2) do
        Thread.new do
          sleep(1)
          queue.complete(job1)
        end
      end

      before do
        queue << job1

        thread1
        thread2
      end

      after do
        thread1.join
        thread2.join
      end

      # tick should not allow for wait skipping, it should just trigger a re-check
      it 'expect not to pass until the queue is actually closed' do
        before = Time.now.to_f
        queue.wait(job1.group_id)
        expect(Time.now.to_f - before).to be >= 1
      end
    end

    context 'when we have non blocking jobs in the queue only' do
      before { queue << OpenStruct.new(group_id: 1, id: 1, call: true, non_blocking?: true) }

      it 'expect not to block' do
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
      let(:thread) do
        Thread.new do
          sleep(0.01)
          queue.complete(job1)
        end
      end

      before do
        thread
        allow(Karafka::App).to receive(:stopping?).and_return(true)
        queue << job1
      end

      after do
        thread.join
      end

      it 'expect to wait' do
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
      let(:group_id) { SecureRandom.hex(6) }

      it 'expect not to wait' do
        queue.wait(group_id)
      end
    end
  end

  describe '#statistics' do
    context 'when there are no jobs' do
      it { expect(queue.statistics).to eq(busy: 0, enqueued: 0, waiting: 0) }
    end

    context 'when there are jobs from one group' do
      let(:job1) { OpenStruct.new(group_id: 1, id: 1, call: true) }
      let(:job2) { OpenStruct.new(group_id: 1, id: 2, call: true) }

      before do
        queue << job1
        queue << job2
      end

      it { expect(queue.statistics).to eq(busy: 2, enqueued: 0, waiting: 0) }
    end

    context 'when there are jobs from multiple groups' do
      before do
        queue << job1
        queue << job2
      end

      it { expect(queue.statistics).to eq(busy: 2, enqueued: 0, waiting: 0) }
    end
  end

  describe '#empty?' do
    let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true) }

    before { queue.register(1) }

    context 'when there are no jobs at all' do
      it { expect(queue.empty?(1)).to be(true) }
    end

    context 'when there are no jobs but async lock has been added' do
      before { queue.lock_async(1, 1) }

      it { expect(queue.empty?(1)).to be(false) }
    end

    context 'when there are jobs from a different subscription group' do
      before { queue << job }

      it { expect(queue.empty?(2)).to be(true) }
    end

    context 'when there are jobs from our subscription group' do
      before { queue << job }

      it { expect(queue.empty?(job.group_id)).to be(false) }
    end

    context 'when there are jobs from our subscription group and locks' do
      before do
        queue << job
        queue.lock_async(1, 1)
      end

      it { expect(queue.empty?(job.group_id)).to be(false) }
    end
  end
end
