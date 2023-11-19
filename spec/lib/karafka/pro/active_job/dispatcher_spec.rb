# frozen_string_literal: true

RSpec.describe_current do
  subject(:dispatcher) { described_class.new }

  before { allow(Time).to receive(:now).and_return(current_time) }

  let(:current_time) { Time.now }

  let(:job_class) do
    Class.new(ActiveJob::Base) do
      extend ::Karafka::ActiveJob::JobExtensions
    end
  end

  let(:job_class2) do
    Class.new(ActiveJob::Base) do
      extend ::Karafka::ActiveJob::JobExtensions

      queue_as :test2

      karafka_options(dispatch_many_method: :produce_many_sync)
    end
  end

  let(:job) { job_class.new }
  let(:serialized_payload) { ActiveSupport::JSON.encode(job.serialize) }

  describe '#dispatch' do
    context 'when we dispatch without any changes to the defaults' do
      before { allow(::Karafka.producer).to receive(:produce_async) }

      it 'expect to use proper encoder and async producer to dispatch the job' do
        dispatcher.dispatch(job)

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
        dispatcher.dispatch(job)

        expect(::Karafka.producer).to have_received(:produce_sync).with(
          topic: job.queue_name,
          payload: serialized_payload
        )
      end
    end

    context 'when we want to dispatch with partitioner using key' do
      let(:expected_args) do
        {
          topic: job.queue_name,
          payload: serialized_payload,
          key: job.job_id
        }
      end

      before do
        job_class.karafka_options(partitioner: ->(job) { job.job_id })
        allow(::Karafka.producer).to receive(:produce_async)
      end

      it 'expect to use its result alongside other options' do
        dispatcher.dispatch(job)

        expect(::Karafka.producer).to have_received(:produce_async).with(expected_args)
      end
    end

    context 'when we want to dispatch with partitioner using partition_key' do
      let(:expected_args) do
        {
          topic: job.queue_name,
          payload: serialized_payload,
          partition_key: job.job_id
        }
      end

      before do
        job_class.karafka_options(partitioner: ->(job) { job.job_id })
        job_class.karafka_options(partition_key_type: :partition_key)
        allow(::Karafka.producer).to receive(:produce_async)
      end

      it 'expect to use its result alongside other options' do
        dispatcher.dispatch(job)

        expect(::Karafka.producer).to have_received(:produce_async).with(expected_args)
      end
    end
  end

  describe '#dispatch_many' do
    let(:jobs) { [job_class.new, job_class.new] }
    let(:jobs_messages) do
      [
        {
          topic: jobs[0].queue_name,
          payload: ActiveSupport::JSON.encode(jobs[0].serialize)
        },
        {
          topic: jobs[1].queue_name,
          payload: ActiveSupport::JSON.encode(jobs[1].serialize)
        }
      ]
    end

    context 'when we dispatch without any changes to the defaults' do
      before { allow(::Karafka.producer).to receive(:produce_many_async) }

      it 'expect to use proper encoder and async producer to dispatch the jobs' do
        dispatcher.dispatch_many(jobs)

        expect(::Karafka.producer).to have_received(:produce_many_async).with(jobs_messages)
      end
    end

    context 'when we want to dispatch sync' do
      before do
        job_class.karafka_options(dispatch_many_method: :produce_many_sync)
        allow(::Karafka.producer).to receive(:produce_many_sync)
      end

      it 'expect to use proper encoder and sync producer to dispatch the jobs' do
        dispatcher.dispatch_many(jobs)

        expect(::Karafka.producer).to have_received(:produce_many_sync).with(jobs_messages)
      end
    end

    context 'when jobs have different dispatch many methods' do
      let(:jobs) { [job_class.new, job_class2.new] }
      let(:jobs_messages) do
        [
          {
            topic: jobs[0].queue_name,
            payload: ActiveSupport::JSON.encode(jobs[0].serialize)
          },
          {
            topic: jobs[1].queue_name,
            payload: ActiveSupport::JSON.encode(jobs[1].serialize)
          }
        ]
      end

      before do
        allow(::Karafka.producer).to receive(:produce_many_async)
        allow(::Karafka.producer).to receive(:produce_many_sync)
      end

      it 'expect to dispatch them with correct dispatching methods' do
        dispatcher.dispatch_many(jobs)

        expect(::Karafka.producer).to have_received(:produce_many_async).with([jobs_messages[0]])
        expect(::Karafka.producer).to have_received(:produce_many_sync).with([jobs_messages[1]])
      end
    end
  end
end
