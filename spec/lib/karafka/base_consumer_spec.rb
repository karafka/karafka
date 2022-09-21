# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    instance = working_class.new
    instance.coordinator = coordinator
    instance.topic = topic
    instance
  end

  let(:coordinator) { build(:processing_coordinator) }
  let(:topic) { build(:routing_topic) }
  let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
  let(:first_message) { instance_double(Karafka::Messages::Message, offset: offset, partition: 0) }
  let(:last_message) { instance_double(Karafka::Messages::Message, offset: offset, partition: 0) }
  let(:offset) { 123 }

  let(:messages) do
    instance_double(
      Karafka::Messages::Messages,
      first: first_message,
      last: last_message,
      metadata: Karafka::Messages::BatchMetadata.new(
        topic: topic.name,
        partition: 0,
        processed_at: Time.now
      )
    )
  end

  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      attr_reader :consumed

      def consume
        self
      end
    end
  end

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(described_class) }

    it { expect { consumer.send(:consume) }.to raise_error NotImplementedError }
  end

  describe '#messages' do
    before { consumer.messages = messages }

    it { expect(consumer.messages).to eq messages }
  end

  describe '#client' do
    before { consumer.client = client }

    it 'expect to return current persisted client' do
      expect(consumer.client).to eq client
    end
  end

  describe '#on_consume and #on_after_consume' do
    let(:consume_with_after) do
      lambda do
        consumer.on_before_consume
        consumer.on_consume
        consumer.on_after_consume
      end
    end

    before do
      coordinator.seek_offset = messages.first.offset
      consumer.coordinator = coordinator
      consumer.client = client
      consumer.messages = messages
      allow(coordinator.pause_tracker).to receive(:pause)
    end

    context 'when everything went ok on consume with manual offset management' do
      before { topic.manual_offset_management = true }

      it { expect { consume_with_after.call }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.consumed') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consume_with_after.call
      end

      it 'expect to never run consumption marking' do
        allow(consumer).to receive(:mark_as_consumed)
        consume_with_after.call
        expect(consumer).not_to have_received(:mark_as_consumed)
      end
    end

    context 'when there was an error on consume with manual offset management' do
      let(:working_class) do
        ClassBuilder.inherit(described_class) do
          attr_reader :consumed

          def consume
            raise StandardError
          end
        end
      end

      it { expect { consume_with_after.call }.not_to raise_error }

      it 'expect to pause based on the first message ever received' do
        consume_with_after.call
        expect(client).to have_received(:pause).with(topic.name, first_message.partition, offset)
      end

      it 'expect to pause with time tracker' do
        consume_with_after.call
        expect(coordinator.pause_tracker).to have_received(:pause)
      end

      it 'expect to track this with an instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to eq(StandardError)
          expect(event.payload[:type]).to eq('consumer.consume.error')
        end
      end
    end

    context 'when everything went ok on consume with automatic offset management' do
      before do
        topic.manual_offset_management = false
        allow(client).to receive(:mark_as_consumed)
      end

      it { expect { consumer.on_consume }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.consumed') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consumer.on_consume
      end

      it 'expect to never run consumption marking' do
        consume_with_after.call
        expect(client).to have_received(:mark_as_consumed).with(last_message)
      end
    end

    context 'when there was an error on consume with automatic offset management' do
      before { topic.manual_offset_management = false }

      let(:working_class) do
        ClassBuilder.inherit(described_class) do
          attr_reader :consumed

          def consume
            raise StandardError
          end
        end
      end

      it { expect { consume_with_after.call }.not_to raise_error }

      it 'expect to pause based on the message offset' do
        consume_with_after.call
        expect(client).to have_received(:pause).with(topic.name, first_message.partition, offset)
      end

      it 'expect to pause with time tracker' do
        consume_with_after.call
        expect(coordinator.pause_tracker).to have_received(:pause)
      end

      it 'expect to track this with an instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to eq(StandardError)
          expect(event.payload[:type]).to eq('consumer.consume.error')
        end
      end
    end
  end

  describe '#on_revoked' do
    context 'when everything went ok on revoked' do
      it { expect { consumer.on_revoked }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.revoked') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consumer.on_revoked
      end

      it 'expect not to run error instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).not_to eq(consumer)
          expect(event.payload[:error]).not_to be_a(StandardError)
          expect(event.payload[:type]).to eq('consumer.revoked.error')
        end

        consumer.on_revoked
      end
    end

    context 'when something goes wrong on revoked' do
      let(:working_class) do
        ClassBuilder.inherit(described_class) do
          def revoked
            raise StandardError
          end
        end
      end

      it { expect { consumer.on_revoked }.not_to raise_error }

      it 'expect to run the error instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to be_a(StandardError)
          expect(event.payload[:type]).to eq('consumer.revoked.error')
        end

        consumer.on_revoked
      end
    end
  end

  describe '#on_shutdown' do
    context 'when everything went ok on shutdown' do
      it { expect { consumer.on_shutdown }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.shutdown') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consumer.on_shutdown
      end

      it 'expect not to run error instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).not_to eq(consumer)
          expect(event.payload[:error]).not_to be_a(StandardError)
          expect(event.payload[:type]).to eq('consumer.shutdown.error')
        end

        consumer.on_shutdown
      end
    end

    context 'when something goes wrong on shutdown' do
      let(:working_class) do
        ClassBuilder.inherit(described_class) do
          def shutdown
            raise StandardError
          end
        end
      end

      it { expect { consumer.on_shutdown }.not_to raise_error }

      it 'expect to run the error instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to be_a(StandardError)
          expect(event.payload[:type]).to eq('consumer.shutdown.error')
        end

        consumer.on_shutdown
      end
    end
  end

  describe '#mark_as_consumed' do
    before { consumer.client = client }

    context 'when marking as consumed was successful' do
      before do
        allow(client).to receive(:mark_as_consumed).and_return(true)

        consumer.send(:mark_as_consumed, last_message)
      end

      it 'expect to proxy pass to client' do
        expect(client).to have_received(:mark_as_consumed).with(last_message)
      end

      it 'epxect to increase seek_offset' do
        expect(consumer.coordinator.seek_offset).to eq(offset + 1)
      end
    end

    context 'when marking as consumed failed' do
      before do
        allow(client).to receive(:mark_as_consumed).and_return(false)

        consumer.send(:mark_as_consumed, last_message)
      end

      it 'expect to proxy pass to client' do
        expect(client).to have_received(:mark_as_consumed).with(last_message)
      end

      it 'epxect to not increase seek_offset' do
        expect(consumer.coordinator.seek_offset).to eq(nil)
      end
    end
  end

  describe '#mark_as_consumed!' do
    before { consumer.client = client }

    context 'when marking as consumed was successful' do
      before do
        allow(client).to receive(:mark_as_consumed!).and_return(true)

        consumer.send(:mark_as_consumed!, last_message)
      end

      it 'expect to proxy pass to client' do
        expect(client).to have_received(:mark_as_consumed!).with(last_message)
      end

      it 'epxect to increase seek_offset' do
        expect(consumer.coordinator.seek_offset).to eq(offset + 1)
      end
    end

    context 'when marking as consumed failed' do
      before do
        allow(client).to receive(:mark_as_consumed!).and_return(false)

        consumer.send(:mark_as_consumed!, last_message)
      end

      it 'expect to proxy pass to client' do
        expect(client).to have_received(:mark_as_consumed!).with(last_message)
      end

      it 'epxect to not increase seek_offset' do
        expect(consumer.coordinator.seek_offset).to eq(nil)
      end
    end
  end

  describe '#seek' do
    let(:new_offset) { rand(0.100) }
    let(:seek) { Karafka::Messages::Seek.new(topic.name, 0, new_offset) }

    before do
      consumer.client = client
      consumer.messages = messages

      allow(client).to receive(:seek)

      consumer.send(:seek, new_offset)
    end

    it 'expect to forward to client using current execution context data' do
      expect(client).to have_received(:seek).with(seek)
    end
  end

  describe '#pause' do
    before do
      consumer.client = client
      consumer.messages = messages

      allow(coordinator.pause_tracker).to receive(:pause)
      allow(client).to receive(:pause)
    end

    context 'when we pause without providing the timeout' do
      let(:expected_args) do
        [
          messages.metadata.topic,
          messages.metadata.partition,
          100
        ]
      end

      before { consumer.send(:pause, 100) }

      it 'expect to pause via client and use pause tracker without any arguments' do
        expect(client).to have_received(:pause).with(*expected_args)
        expect(coordinator.pause_tracker).to have_received(:pause).with(no_args)
      end
    end

    context 'when we pause providing the timeout' do
      let(:expected_args) do
        [
          messages.metadata.topic,
          messages.metadata.partition,
          100
        ]
      end

      before { consumer.send(:pause, 100, 2_000) }

      it 'expect to pause via client and use pause tracker with provided timeout' do
        expect(client).to have_received(:pause).with(*expected_args)
        expect(coordinator.pause_tracker).to have_received(:pause).with(2_000)
      end
    end
  end

  describe '#resume' do
    before do
      allow(coordinator.pause_tracker).to receive(:expire)

      consumer.send(:resume)
    end

    it 'expect to expire the pause tracker' do
      expect(coordinator.pause_tracker).to have_received(:expire)
    end
  end
end
