# frozen_string_literal: true

RSpec.describe_current do
  subject(:dispatcher) { described_class.new }

  let(:job_class) do
    Class.new(ActiveJob::Base) do
      extend ::Karafka::ActiveJob::JobExtensions
    end
  end

  let(:job) { job_class.new }
  let(:serialized_payload) { ActiveSupport::JSON.encode(job.serialize) }

  context 'when we dispatch without any changes to the defaults' do
    before { allow(::Karafka.producer).to receive(:produce_async) }

    it 'expect to use proper encoder and async producer to dispatch the job' do
      dispatcher.call(job)

      expect(::Karafka.producer).to have_received(:produce_async).with(
        topic: job.queue_name,
        payload: serialized_payload
      )
    end
  end

  context 'when we want to dispatch sync' do
    before do
      job_class.karafka_options(dispatch_method: :produce_sync)
      allow(::Karafka.producer).to receive(:produce_sync)
    end

    it 'expect to use proper encoder and sync producer to dispatch the job' do
      dispatcher.call(job)

      expect(::Karafka.producer).to have_received(:produce_sync).with(
        topic: job.queue_name,
        payload: serialized_payload
      )
    end
  end
end
