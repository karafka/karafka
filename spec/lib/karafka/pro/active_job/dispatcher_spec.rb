# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:dispatcher) { described_class.new }

  before { allow(Time).to receive(:now).and_return(current_time) }

  let(:current_time) { Time.now }

  let(:job_class) do
    Class.new(ActiveJob::Base) do
      extend Karafka::ActiveJob::JobExtensions
    end
  end

  let(:job_class2) do
    Class.new(ActiveJob::Base) do
      extend Karafka::ActiveJob::JobExtensions

      queue_as :test2

      karafka_options(dispatch_many_method: :produce_many_sync)
    end
  end

  let(:job) { job_class.new }
  let(:serialized_payload) { ActiveSupport::JSON.encode(job.serialize) }

  describe "#dispatch" do
    context "when we dispatch without any changes to the defaults" do
      before { allow(Karafka.producer).to receive(:produce_async) }

      it "expect to use proper encoder and async producer to dispatch the job" do
        dispatcher.dispatch(job)

        expect(Karafka.producer).to have_received(:produce_async).with(
          topic: job.queue_name,
          payload: serialized_payload
        )
      end
    end

    context "when we dispatch with a custom producer" do
      let(:variant) { Karafka.producer.with(max_wait_timeout: 100) }

      before do
        allow(variant).to receive(:produce_async)
        allow(Karafka.producer).to receive(:produce_async)

        job_class.karafka_options(producer: ->(_) { variant })

        dispatcher.dispatch(job)
      end

      it "expect to use proper producer to dispatch the job" do
        expect(variant).to have_received(:produce_async).with(
          topic: job.queue_name,
          payload: serialized_payload
        )
      end

      it "expect not to use the default producer" do
        expect(Karafka.producer).not_to have_received(:produce_async)
      end
    end

    context "when we want to dispatch sync" do
      before do
        job_class.karafka_options(dispatch_method: :produce_sync)
        allow(Karafka.producer).to receive(:produce_sync)
      end

      it "expect to use proper encoder and sync producer to dispatch the job" do
        dispatcher.dispatch(job)

        expect(Karafka.producer).to have_received(:produce_sync).with(
          topic: job.queue_name,
          payload: serialized_payload
        )
      end
    end

    context "when we want to dispatch with partitioner using key" do
      let(:expected_args) do
        {
          topic: job.queue_name,
          payload: serialized_payload,
          key: job.job_id
        }
      end

      before do
        job_class.karafka_options(partitioner: ->(job) { job.job_id })
        allow(Karafka.producer).to receive(:produce_async)
      end

      it "expect to use its result alongside other options" do
        dispatcher.dispatch(job)

        expect(Karafka.producer).to have_received(:produce_async).with(expected_args)
      end
    end

    context "when we want to dispatch with partitioner using partition_key" do
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
        allow(Karafka.producer).to receive(:produce_async)
      end

      it "expect to use its result alongside other options" do
        dispatcher.dispatch(job)

        expect(Karafka.producer).to have_received(:produce_async).with(expected_args)
      end
    end
  end

  describe "#dispatch_many" do
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

    context "when we dispatch without any changes to the defaults" do
      before { allow(Karafka.producer).to receive(:produce_many_async) }

      it "expect to use proper encoder and async producer to dispatch the jobs" do
        dispatcher.dispatch_many(jobs)

        expect(Karafka.producer).to have_received(:produce_many_async).with(jobs_messages)
      end
    end

    context "when we want to dispatch sync" do
      before do
        job_class.karafka_options(dispatch_many_method: :produce_many_sync)
        allow(Karafka.producer).to receive(:produce_many_sync)
      end

      it "expect to use proper encoder and sync producer to dispatch the jobs" do
        dispatcher.dispatch_many(jobs)

        expect(Karafka.producer).to have_received(:produce_many_sync).with(jobs_messages)
      end
    end

    context "when we want to dispatch with custom producer" do
      let(:variant) { Karafka.producer.with(max_wait_timeout: 100) }

      before do
        job_class.karafka_options(producer: ->(_) { variant })
        allow(Karafka.producer).to receive(:produce_many_async)
        allow(variant).to receive(:produce_many_async)
        dispatcher.dispatch_many(jobs)
      end

      it "expect to use proper producer to dispatch the jobs" do
        expect(variant).to have_received(:produce_many_async).with(jobs_messages)
      end

      it "expect not to use the default producer" do
        expect(Karafka.producer).not_to have_received(:produce_many_async)
      end
    end

    context "when jobs have different dispatch many methods" do
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
        allow(Karafka.producer).to receive(:produce_many_async)
        allow(Karafka.producer).to receive(:produce_many_sync)
      end

      it "expect to dispatch them with correct dispatching methods" do
        dispatcher.dispatch_many(jobs)

        expect(Karafka.producer).to have_received(:produce_many_async).with([jobs_messages[0]])
        expect(Karafka.producer).to have_received(:produce_many_sync).with([jobs_messages[1]])
      end
    end
  end

  describe "#dispatch_at" do
    let(:timestamp) { current_time + 3600 }
    let(:proxy_topic) { "scheduled_jobs" }
    let(:proxy_message) do
      {
        topic: proxy_topic,
        payload: serialized_payload,
        epoch: timestamp.to_i,
        envelope: {
          topic: proxy_topic
        }
      }
    end

    before do
      job_class.karafka_options(scheduled_messages_topic: proxy_topic)
      allow(Karafka::Pro::ScheduledMessages).to receive(:schedule).and_return(proxy_message)
      allow(Karafka.producer).to receive(:produce_async)
    end

    it "expects to use scheduled messages feature with correct parameters" do
      dispatcher.dispatch_at(job, timestamp)

      expect(Karafka::Pro::ScheduledMessages).to have_received(:schedule).with(
        message: {
          topic: job.queue_name,
          payload: serialized_payload
        },
        epoch: timestamp.to_i,
        envelope: {
          topic: proxy_topic
        }
      )

      expect(Karafka.producer).to have_received(:produce_async).with(proxy_message)
    end

    context "when scheduled_messages_topic is not defined" do
      it "raises an error" do
        expect { job_class.karafka_options(scheduled_messages_topic: nil) }
          .to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end

    context "when scheduled_messages_topic is not scheduled messages topic" do
      before do
        allow(Karafka::Pro::ScheduledMessages).to receive(:schedule).and_call_original
        job_class.karafka_options(scheduled_messages_topic: "not-a-proper-proxy")
      end

      it "raises an error" do
        expect { dispatcher.dispatch_at(job, timestamp) }
          .to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end
  end
end
