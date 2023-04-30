# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    described_class.new.tap do |instance|
      instance.client = client
      instance.coordinator = coordinator
      instance.singleton_class.include(strategy)
    end
  end

  let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
  let(:coordinator) { build(:processing_coordinator_pro, topic: topic) }
  let(:topic) { build(:routing_topic) }
  let(:messages) { [message1, message2] }
  let(:message1) { build(:messages_message, raw_payload: payload1.to_json) }
  let(:message2) { build(:messages_message, raw_payload: payload2.to_json) }
  let(:payload1) { { '1' => '2' } }
  let(:payload2) { { '3' => '4' } }
  let(:strategy) { Karafka::Pro::Processing::Strategies::Aj::Mom }

  before do
    coordinator.start(messages)
    coordinator.increment
  end

  it { expect(described_class).to be < Karafka::BaseConsumer }

  describe '#on_before_enqueue behaviour' do
    before { allow(consumer).to receive(:pause) }

    context 'when it is not a lrj' do
      it 'expect not to pause' do
        consumer.on_before_enqueue

        expect(consumer).not_to have_received(:pause)
      end
    end

    context 'when it is a lrj' do
      let(:strategy) { Karafka::Pro::Processing::Strategies::Aj::LrjMom }

      before do
        consumer.messages = messages
        topic.long_running_job true
      end

      it 'expect to pause forever on our first message' do
        consumer.on_before_enqueue

        expect(consumer).to have_received(:pause).with(message1.offset, 1_000_000_000_000, false)
      end
    end
  end

  describe '#consume' do
    context 'when messages are available to the consumer and it is not a lrj' do
      before do
        consumer.messages = messages

        allow(client).to receive(:mark_as_consumed).with(messages.first).and_return(true)
        allow(client).to receive(:mark_as_consumed).with(messages.last).and_return(true)

        allow(ActiveJob::Base).to receive(:execute).with(payload1)
        allow(ActiveJob::Base).to receive(:execute).with(payload2)
      end

      it 'expect to decode them and run active job executor' do
        consumer.consume

        expect(ActiveJob::Base).to have_received(:execute).with(payload1)
        expect(ActiveJob::Base).to have_received(:execute).with(payload2)
      end

      it 'expect to mark as consumed on each message' do
        consumer.consume

        expect(client).to have_received(:mark_as_consumed).with(messages.first)
        expect(client).to have_received(:mark_as_consumed).with(messages.last)
      end
    end

    context 'when messages are available to the consumer and it is virtual partition' do
      let(:strategy) { Karafka::Pro::Processing::Strategies::Aj::MomVp }

      let(:topic) do
        topic = build(:routing_topic)
        topic.virtual_partitions(partitioner: ->(_) {})
        topic
      end

      before do
        consumer.messages = messages

        allow(coordinator).to receive(:revoked?).and_return(false)
        allow(client).to receive(:mark_as_consumed)

        allow(ActiveJob::Base).to receive(:execute).with(payload1)
        allow(ActiveJob::Base).to receive(:execute).with(payload2)
      end

      it 'expect to decode them and run active job executor' do
        consumer.consume

        expect(ActiveJob::Base).to have_received(:execute).with(payload1)
        expect(ActiveJob::Base).to have_received(:execute).with(payload2)
      end

      it 'expect to mark each message during consumption' do
        consumer.consume

        expect(client).to have_received(:mark_as_consumed).exactly(2).times
      end
    end

    context 'when messages are available but partition got revoked prior to processing' do
      before do
        consumer.messages = messages
        consumer.coordinator.decrement
        consumer.on_revoked

        allow(client).to receive(:mark_as_consumed).with(messages.first).and_return(true)
        allow(client).to receive(:mark_as_consumed).with(messages.last).and_return(true)

        allow(ActiveJob::Base).to receive(:execute).with(payload1)
        allow(ActiveJob::Base).to receive(:execute).with(payload2)
      end

      it 'expect not to run anything' do
        consumer.consume

        expect(ActiveJob::Base).not_to have_received(:execute).with(payload1)
        expect(ActiveJob::Base).not_to have_received(:execute).with(payload2)
      end
    end
  end
end
