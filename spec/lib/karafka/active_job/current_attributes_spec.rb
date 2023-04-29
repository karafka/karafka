# frozen_string_literal: true

require 'karafka/active_job/current_attributes'

module Karafka
  class CurrentAttrTest < ActiveSupport::CurrentAttributes
    attribute :user_id
  end
end

RSpec.describe_current do
  before { Karafka::ActiveJob::CurrentAttributes.persist('Karafka::CurrentAttrTest') }

  context 'dispatch' do
    subject(:dispatcher) { Karafka::ActiveJob::Dispatcher.new }

    let(:job_class) do
      Class.new(ActiveJob::Base) do
        extend ::Karafka::ActiveJob::JobExtensions
      end
    end

    describe '#dispatch' do
      before { allow(::Karafka.producer).to receive(:produce_async) }

      let(:job) { job_class.new }
      let(:serialized_job) do
        ActiveSupport::JSON.encode(job.serialize.merge({ 'cattr' => { 'user_id' => 1 } }))
      end

      it 'expect to serialize current attributes as part of the job' do
        with_context(:user_id, 1) { dispatcher.dispatch(job) }

        expect(::Karafka.producer).to have_received(:produce_async).with(
          topic: job.queue_name,
          payload: serialized_job
        )
      end
    end

    describe '#dispatch_many' do
      before { allow(::Karafka.producer).to receive(:produce_many_async) }

      let(:jobs) { [job_class.new, job_class.new] }
      let(:jobs_messages) do
        [
          {
            topic: jobs[0].queue_name,
            payload: ActiveSupport::JSON.encode(
              jobs[0].serialize.merge({ 'cattr' => { 'user_id' => 1 } })
            )
          },
          {
            topic: jobs[1].queue_name,
            payload: ActiveSupport::JSON.encode(
              jobs[1].serialize.merge({ 'cattr' => { 'user_id' => 1 } })
            )
          }
        ]
      end

      it 'expect to serialize current attributes as part of the jobs' do
        with_context(:user_id, 1) { dispatcher.dispatch_many(jobs) }

        expect(::Karafka.producer).to have_received(:produce_many_async).with(jobs_messages)
      end
    end
  end

  context 'consume' do
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
      build(:messages_message, raw_payload: payload.merge('cattr' => { 'user_id' => 1 }).to_json)
    end
    let(:payload) { { 'foo' => 'bar' } }

    before do
      allow(Karafka::App).to receive(:stopping?).and_return(false)

      allow(client).to receive(:mark_as_consumed).with(message)
      allow(ActiveJob::Base).to receive(:execute).with(payload)
      allow(Karafka::CurrentAttrTest).to receive(:set).with({ 'user_id' => 1 })

      consumer.messages = [message]
    end

    it 'expect to set current attributes before running the job' do
      consumer.consume

      expect(Karafka::CurrentAttrTest).to have_received(:set).with({ 'user_id' => 1 })
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
