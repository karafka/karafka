# frozen_string_literal: true

RSpec.describe_current do
  subject(:adapter) { ActiveJob::QueueAdapters::KarafkaAdapter.new }

  let(:job) { ActiveJob::Base.new }

  describe '#enqueue_at' do
    it 'expect to indicate, that it is not supported' do
      expect { adapter.enqueue_at(job, 5.minutes.from_now) }.to raise_error(NotImplementedError)
    end
  end

  describe '#enqueue' do
    before do
      allow(Karafka::App.config.internal.active_job.dispatcher).to receive(:call).with(job)
    end

    it 'expect to delegate to a proper dispatcher based on the configuration' do
      adapter.enqueue(job)
      expect(Karafka::App.config.internal.active_job.dispatcher).to have_received(:call).with(job)
    end
  end
end
