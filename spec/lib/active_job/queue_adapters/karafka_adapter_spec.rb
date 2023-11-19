# frozen_string_literal: true

RSpec.describe_current do
  subject(:adapter) { ActiveJob::QueueAdapters::KarafkaAdapter.new }

  let(:job) { ActiveJob::Base.new }
  let(:dispatcher) { Karafka::App.config.internal.active_job.dispatcher }

  describe '#enqueue_at' do
    it 'expect to indicate, that it is not supported' do
      expect { adapter.enqueue_at(job, 5.minutes.from_now) }.to raise_error(NotImplementedError)
    end
  end

  describe '#enqueue' do
    before do
      allow(dispatcher).to receive(:dispatch).with(job)
    end

    it 'expect to delegate to a proper dispatcher based on the configuration' do
      adapter.enqueue(job)
      expect(dispatcher).to have_received(:dispatch).with(job)
    end
  end

  describe '#enqueue_all' do
    let(:jobs) { [ActiveJob::Base.new, ActiveJob::Base.new] }

    before do
      allow(dispatcher).to receive(:dispatch_many).with(jobs)
    end

    it 'expect to delegate to a proper dispatcher based on the configuration' do
      adapter.enqueue_all(jobs)
      expect(dispatcher).to have_received(:dispatch_many).with(jobs)
    end
  end
end
