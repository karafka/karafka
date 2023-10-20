# frozen_string_literal: true

require 'karafka/active_job/current_attributes'

module Karafka
  class CurrentAttrTest < ActiveSupport::CurrentAttributes # :nodoc:
    attribute :user_id
  end
end

RSpec.describe_current do
  before { described_class.persist('Karafka::CurrentAttrTest') }

  context 'when dispatching jobs' do
    subject(:dispatcher) { Karafka::ActiveJob::Dispatcher.new }

    let(:job_class) do
      Class.new(ActiveJob::Base) do
        extend ::Karafka::ActiveJob::JobExtensions
      end
    end

    describe '#dispatch' do
      before { allow(::Karafka.producer).to receive(:produce_async) }

      let(:job) { job_class.new }

      it 'expect to serialize current attributes as part of the job' do
        with_context(:user_id, 1) do
          dispatcher.dispatch(job)
        end

        expect(::Karafka.producer).to have_received(:produce_async).with(
          hash_including(topic: job.queue_name)
        )
      end
    end

    describe '#dispatch_many' do
      before { allow(::Karafka.producer).to receive(:produce_many_async) }

      let(:jobs) { [job_class.new, job_class.new] }
      let(:jobs_messages) do
        [
          hash_including(topic: jobs[0].queue_name),
          hash_including(topic: jobs[1].queue_name)
        ]
      end

      it 'expect to serialize current attributes as part of the jobs' do
        with_context(:user_id, 1) do
          jobs_messages
          dispatcher.dispatch_many(jobs)
        end

        expect(::Karafka.producer).to have_received(:produce_many_async).with(jobs_messages)
      end
    end
  end

  context 'when consuming jobs' do
    subject(:consumer) do
      consumer = Karafka::ActiveJob::Consumer.new
      consumer.client = client
      consumer.coordinator = coordinator
      consumer.singleton_class.include Karafka::Processing::Strategies::Default
      consumer
    end

    let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
    let(:coordinator) { build(:processing_coordinator, seek_offset: 0) }
    let(:message) do
      build(:messages_message, raw_payload: payload.merge('cattr_0' => { 'user_id' => 1 }).to_json)
    end
    let(:payload) { { 'foo' => 'bar' } }

    before do
      allow(Karafka::App).to receive(:stopping?).and_return(false)

      allow(client).to receive(:mark_as_consumed).with(message)
      allow(client).to receive(:assignment_lost?).and_return(false)
      allow(ActiveJob::Base).to receive(:execute).with(payload)
      allow(Karafka::CurrentAttrTest).to receive(:user_id=).with(1)

      consumer.messages = [message]
    end

    it 'expect to set current attributes before running the job' do
      consumer.consume

      expect(Karafka::CurrentAttrTest).to have_received(:user_id=).with(1)
    end
  end

  private

  def with_context(attr, value)
    Karafka::CurrentAttrTest.send("#{attr}=", value)
    yield
  ensure
    Karafka::CurrentAttrTest.reset_all
  end
end
