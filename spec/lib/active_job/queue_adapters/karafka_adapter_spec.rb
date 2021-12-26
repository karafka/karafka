# frozen_string_literal: true

RSpec.describe_current do
  subject(:adapter) { described_class.new }

  let(:job) { ActiveJob::Base.new }

  describe '#enqueue_at' do
    it 'expect to indicate, that it is not supported' do
      expect { adapter.enqueue_at(job, 5.minutes.from_now) }.to raise_error(NotImplementedError)
    end
  end

  describe '#enqueue' do
    let(:serialized_payload) { ActiveSupport::JSON.encode(job.serialize) }

    before do
      allow(::Karafka.producer).to receive(:produce_async).with(
        topic: job.queue_name,
        payload: serialized_payload
      )
    end

    it 'expect to use proper encoder and async producer to dispatch the job' do
      adapter.enqueue(job)

      expect(::Karafka.producer).to have_received(:produce_async)
    end
  end
end
