# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    instance = working_class.new
    instance.pause = pause
    instance.topic = topic
    instance
  end

  let(:pause) { Karafka::TimeTrackers::Pause.new }
  let(:topic) { build(:routing_topic) }

  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      attr_reader :consumed

      def initialize
        super
        @consumed = false
      end

      def consume
        @consumed = true
        self
      end
    end
  end

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(described_class) }

    it { expect { consumer.send(:consume) }.to raise_error NotImplementedError }
  end

  describe '#messages' do
    let(:messages) { instance_double(Karafka::Messages::Messages) }

    before { consumer.messages = messages }

    it { expect(consumer.messages).to eq messages }
  end

  describe '#client' do
    let(:client) { instance_double(Karafka::Connection::Client) }

    before { consumer.client = client }

    it 'expect to return current persisted client' do
      expect(consumer.client).to eq client
    end
  end

  describe '#on_consume' do

    before { consumer.pause = pause }

    context 'when everything went ok on consume with manual offset management' do
      before { topic.manual_offset_management = true }

      it { expect { consumer.on_consume }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.consume') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consumer.on_consume
      end

      it 'expect to never run consumption marking' do
        allow(consumer).to receive(:mark_as_consumed)
        consumer.on_consume
        expect(consumer).not_to have_received(:mark_as_consumed)
      end
    end

    context 'when there was an error on consume with manual offset management' do
      pending
    end

    context 'when everything went ok on consume with automatic offset management' do
      pending
    end

    context 'when there was an error on consume with automatic offset management' do
      pending
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
        Karafka.monitor.subscribe('consumer.revoked.error') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to be_a(StandardError)
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
        Karafka.monitor.subscribe('consumer.shutdown.error') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to be_a(StandardError)
        end

        consumer.on_shutdown
      end
    end
  end

  describe '#mark_as_consumed' do
    let(:client) { instance_double(Karafka::Connection::Client) }
    let(:message) { instance_double(Karafka::Messages::Message, offset: offset) }
    let(:offset) { rand.to_i }

    before do
      consumer.client = client

      allow(client).to receive(:mark_as_consumed)

      consumer.send(:mark_as_consumed, message)
    end

    it 'expect to proxy pass to client' do
      expect(client).to have_received(:mark_as_consumed).with(message)
    end

    it 'epxect to increase seek_offset' do
      expect(consumer.instance_variable_get(:@seek_offset)).to eq(offset + 1)
    end
  end

  describe '#mark_as_consumed!' do
    let(:client) { instance_double(Karafka::Connection::Client) }
    let(:message) { instance_double(Karafka::Messages::Message, offset: offset) }
    let(:offset) { rand.to_i }

    before do
      consumer.client = client

      allow(client).to receive(:mark_as_consumed!)

      consumer.send(:mark_as_consumed!, message)
    end

    it 'expect to proxy pass to client' do
      expect(client).to have_received(:mark_as_consumed!).with(message)
    end

    it 'epxect to increase seek_offset' do
      expect(consumer.instance_variable_get(:@seek_offset)).to eq(offset + 1)
    end
  end
end
