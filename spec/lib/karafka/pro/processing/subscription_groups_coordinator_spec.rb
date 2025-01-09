# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:coordinator) { described_class.instance }
  let(:subscription_group) { build(:routing_subscription_group) }
  let(:lock_id) { 'lock_id' }
  let(:jobs_queue) { Karafka::Pro::Processing::JobsQueue.new }

  before do
    allow(coordinator).to receive(:jobs_queue).and_return(jobs_queue)
    allow(jobs_queue).to receive(:lock_async)
    allow(jobs_queue).to receive(:unlock_async)
  end

  describe '#pause' do
    let(:kwargs) { { timeout: 10_000 } }

    it 'calls lock_async on the jobs queue with the correct parameters' do
      coordinator.pause(subscription_group, lock_id, **kwargs)

      expect(jobs_queue)
        .to have_received(:lock_async)
        .with(subscription_group.id, lock_id, **kwargs)
    end

    context 'without lock_id' do
      it 'still calls lock_async with correct parameters, excluding lock_id' do
        coordinator.pause(subscription_group, nil, **kwargs)

        expect(jobs_queue)
          .to have_received(:lock_async)
          .with(subscription_group.id, nil, **kwargs)
      end
    end
  end

  describe '#resume' do
    it 'calls unlock_async on the jobs queue with the correct parameters' do
      coordinator.resume(subscription_group, lock_id)

      expect(jobs_queue)
        .to have_received(:unlock_async)
        .with(subscription_group.id, lock_id)
    end

    context 'without lock_id' do
      it 'still calls unlock_async with correct parameters, excluding lock_id' do
        coordinator.resume(subscription_group, nil)

        expect(jobs_queue)
          .to have_received(:unlock_async)
          .with(subscription_group.id, nil)
      end
    end
  end
end
