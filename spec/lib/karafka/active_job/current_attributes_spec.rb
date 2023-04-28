# frozen_string_literal: true

require 'karafka/active_job/current_attributes'

module Karafka
  class CurrentAttrTest < ActiveSupport::CurrentAttributes
    attribute :user_id
  end
end

RSpec.describe_current do
  before { Karafka::ActiveJob::CurrentAttributes.persist("Karafka::CurrentAttrTest") }

  context "dispatch" do
    subject(:dispatcher) { Karafka::ActiveJob::Dispatcher.new }

    let(:job_class) do
      Class.new(ActiveJob::Base) do
        extend ::Karafka::ActiveJob::JobExtensions
      end
    end

    describe '#dispatch' do
      before { allow(::Karafka.producer).to receive(:produce_async) }

      let(:job) { job_class.new }
      let(:serialized_job) { ActiveSupport::JSON.encode(job.serialize.merge({"cattr" => { "user_id" => 1 }})) }

      it 'expect to serialize current attributes as part of the job' do
        with_context(:user_id, 1) do
          dispatcher.dispatch(job)
        end

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
            payload: ActiveSupport::JSON.encode(jobs[0].serialize.merge({"cattr" => { "user_id" => 1 }}))
          },
          {
            topic: jobs[1].queue_name,
            payload: ActiveSupport::JSON.encode(jobs[1].serialize.merge({"cattr" => { "user_id" => 1 }}))
          }
        ]
      end

      it 'expect to serialize current attributes as part of the jobs' do
        with_context(:user_id, 1) do
          dispatcher.dispatch_many(jobs)
        end

        expect(::Karafka.producer).to have_received(:produce_many_async).with(jobs_messages)
      end
    end
  end

end
