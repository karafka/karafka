# frozen_string_literal: true

require "karafka/active_job/current_attributes"

module Karafka
  class CurrentAttrTest < ActiveSupport::CurrentAttributes # :nodoc:
    attribute :user_id
  end

  class CurrentAttrSecondTest < ActiveSupport::CurrentAttributes # :nodoc:
    attribute :tenant, :account
    attribute "region"

    def account=(value)
      super
      raise StandardError if value == "failing"
    end
  end
end

RSpec.describe_current do
  before { described_class.persist("Karafka::CurrentAttrTest") }

  after do
    Karafka::ActiveJob::Dispatcher._cattr_klasses.clear
    Karafka::ActiveJob::Consumer._cattr_klasses.clear
  end

  context "when dispatching jobs" do
    subject(:dispatcher) { Karafka::ActiveJob::Dispatcher.new }

    let(:job_class) do
      Class.new(ActiveJob::Base) do
        extend Karafka::ActiveJob::JobExtensions
      end
    end

    describe "#dispatch" do
      before { allow(Karafka.producer).to receive(:produce_async) }

      let(:job) { job_class.new }

      it "expect to serialize current attributes as part of the job" do
        with_context(:user_id, 1) do
          dispatcher.dispatch(job)
        end

        expect(Karafka.producer).to have_received(:produce_async).with(
          hash_including(topic: job.queue_name)
        )
      end
    end

    describe "#dispatch_many" do
      before { allow(Karafka.producer).to receive(:produce_many_async) }

      let(:jobs) { [job_class.new, job_class.new] }
      let(:jobs_messages) do
        [
          hash_including(topic: jobs[0].queue_name),
          hash_including(topic: jobs[1].queue_name)
        ]
      end

      it "expect to serialize current attributes as part of the jobs" do
        with_context(:user_id, 1) do
          jobs_messages
          dispatcher.dispatch_many(jobs)
        end

        expect(Karafka.producer).to have_received(:produce_many_async).with(jobs_messages)
      end
    end
  end

  context "when consuming jobs" do
    subject(:consumer) do
      consumer = Karafka::ActiveJob::Consumer.new
      consumer.client = client
      consumer.coordinator = coordinator
      consumer.singleton_class.include Karafka::Processing::ConsumerGroups::Strategies::Default
      consumer
    end

    let(:client) { instance_double(Karafka::Connection::ConsumerGroups::Client, pause: true) }
    let(:coordinator) { build(:processing_coordinator, seek_offset: 0) }
    let(:message) do
      build(:messages_message, raw_payload: payload.merge("cattr_0" => { "user_id" => 1 }).to_json)
    end
    let(:payload) { { "foo" => "bar" } }

    before do
      allow(Karafka::App).to receive(:stopping?).and_return(false)

      allow(client).to receive(:mark_as_consumed).with(message)
      allow(client).to receive(:assignment_lost?).and_return(false)
      allow(ActiveJob::Base).to receive(:execute).with(payload)
      allow(Karafka::CurrentAttrTest).to receive(:user_id=).with(1)

      consumer.messages = [message]
    end

    it "expect to set current attributes before running the job" do
      consumer.consume

      expect(Karafka::CurrentAttrTest).to have_received(:user_id=).with(1)
    end

    context "when the job raises" do
      before do
        allow(Karafka::CurrentAttrTest).to receive(:reset)
        allow(ActiveJob::Base).to receive(:execute).and_raise(StandardError)
      end

      it "expect to reset current attributes despite the error so they do not leak" do
        expect { consumer.consume }.to raise_error(StandardError)
        expect(Karafka::CurrentAttrTest).to have_received(:reset)
      end
    end
  end

  context "when restoring current attributes from consumed jobs" do
    subject(:consumer) do
      consumer = Karafka::ActiveJob::Consumer.new
      consumer.client = client
      consumer.coordinator = coordinator
      consumer.singleton_class.include Karafka::Processing::ConsumerGroups::Strategies::Default
      consumer
    end

    let(:client) { instance_double(Karafka::Connection::ConsumerGroups::Client, pause: true) }
    let(:coordinator) { build(:processing_coordinator, seek_offset: 0) }
    let(:message) { build(:messages_message, raw_payload: { "foo" => "bar" }.merge(cattrs).to_json) }
    let(:executed) { [] }

    before do
      described_class.persist("Karafka::CurrentAttrSecondTest")

      allow(Karafka::App).to receive(:stopping?).and_return(false)
      allow(client).to receive(:mark_as_consumed).with(message)
      allow(client).to receive(:assignment_lost?).and_return(false)
      allow(ActiveJob::Base).to receive(:execute) do
        executed << [
          Karafka::CurrentAttrTest.user_id,
          Karafka::CurrentAttrSecondTest.tenant,
          Karafka::CurrentAttrSecondTest.account,
          Karafka::CurrentAttrSecondTest.region
        ]
      end

      consumer.messages = [message]
    end

    context "when all attributes are declared" do
      let(:cattrs) do
        {
          "cattr_0" => { "user_id" => 1 },
          "cattr_1" => { "tenant" => "t1", "account" => "a1", "region" => "eu" }
        }
      end

      it "expect to set them for the job and reset them afterwards" do
        consumer.consume

        expect(executed).to eq([[1, "t1", "a1", "eu"]])
        expect(Karafka::CurrentAttrTest.user_id).to be_nil
        expect(Karafka::CurrentAttrSecondTest.tenant).to be_nil
        expect(Karafka::CurrentAttrSecondTest.region).to be_nil
      end
    end

    context "when one of the attributes is not declared" do
      let(:cattrs) { { "cattr_0" => { "user_id" => 1, "nope" => 2 } } }

      it "expect to raise without running the job and leave no values behind" do
        expect { consumer.consume }.to raise_error(ArgumentError, /nope/)
        expect(executed).to be_empty
        expect(Karafka::CurrentAttrTest.user_id).to be_nil
      end
    end

    context "when a key names a class level writer that is not an attribute" do
      let(:cattrs) { { "cattr_0" => { "defaults" => { "user_id" => 1 } } } }

      it "expect to raise and not change the class" do
        defaults = Karafka::CurrentAttrTest.defaults

        expect { consumer.consume }.to raise_error(ArgumentError, /defaults/)
        expect(Karafka::CurrentAttrTest.defaults).to be(defaults)
      end
    end

    context "when attributes are given as pairs instead of a hash" do
      let(:cattrs) { { "cattr_0" => [["user_id", 1], ["nope", 2]] } }

      it "expect to raise and leave no values behind" do
        expect { consumer.consume }.to raise_error(ArgumentError, /must be a Hash/)
        expect(executed).to be_empty
        expect(Karafka::CurrentAttrTest.user_id).to be_nil
      end
    end

    ["x", nil].each do |attributes|
      context "when attributes are #{attributes.inspect}" do
        let(:cattrs) { { "cattr_0" => attributes } }

        it "expect to raise" do
          expect { consumer.consume }.to raise_error(ArgumentError, /must be a Hash/)
          expect(executed).to be_empty
        end
      end
    end

    context "when a declared writer raises after setting the value" do
      let(:cattrs) do
        {
          "cattr_0" => { "user_id" => 1 },
          "cattr_1" => { "tenant" => "t1", "account" => "failing" }
        }
      end

      it "expect to reset all classes" do
        expect { consumer.consume }.to raise_error(StandardError)
        expect(executed).to be_empty
        expect(Karafka::CurrentAttrTest.user_id).to be_nil
        expect(Karafka::CurrentAttrSecondTest.tenant).to be_nil
        expect(Karafka::CurrentAttrSecondTest.account).to be_nil
      end
    end

    context "when a second class has an undeclared attribute" do
      let(:cattrs) do
        {
          "cattr_0" => { "user_id" => 1 },
          "cattr_1" => { "tenant" => "t1", "nope" => 2 }
        }
      end

      it "expect to reset all classes" do
        expect { consumer.consume }.to raise_error(ArgumentError, /nope/)
        expect(Karafka::CurrentAttrTest.user_id).to be_nil
        expect(Karafka::CurrentAttrSecondTest.tenant).to be_nil
      end
    end
  end

  private

  def with_context(attr, value)
    Karafka::CurrentAttrTest.send("#{attr}=", value)
    yield
  ensure
    # Rails 8.1 renamed reset_all to clear_all, support both for backward compatibility
    if Karafka::CurrentAttrTest.respond_to?(:clear_all)
      Karafka::CurrentAttrTest.clear_all
    else
      Karafka::CurrentAttrTest.reset_all
    end
  end
end
