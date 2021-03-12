# frozen_string_literal: true

RSpec.describe Karafka::BaseConsumer do
  subject(:base_consumer) { working_class.new }

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

    it { expect { base_consumer.send(:consume) }.to raise_error NotImplementedError }
  end

  describe '#messages' do
    let(:messages) { instance_double(Karafka::Messages::Messages) }

    before { base_consumer.messages = messages }

    it { expect(base_consumer.messages).to eq messages }
  end

  describe '#client' do
    let(:client) { instance_double(Karafka::Connection::Client) }

    before { base_consumer.client = client }

    it 'expect to return current persisted client' do
      expect(base_consumer.send(:client)).to eq client
    end
  end

  describe '#mark_as_consumed' do
    let(:client) { instance_double(Karafka::Connection::Client) }
    let(:message) { instance_double(Karafka::Messages::Message, offset: offset) }
    let(:offset) { rand.to_i }

    before do
      base_consumer.client = client

      allow(client).to receive(:mark_as_consumed)

      base_consumer.send(:mark_as_consumed, message)
    end

    it 'expect to proxy pass to client' do
      expect(client).to have_received(:mark_as_consumed).with(message)
    end

    it 'epxect to increase seek_offset' do
      expect(base_consumer.instance_variable_get(:@seek_offset)).to eq(offset + 1)
    end
  end

  describe '#mark_as_consumed!' do
    let(:client) { instance_double(Karafka::Connection::Client) }
    let(:message) { instance_double(Karafka::Messages::Message, offset: offset) }
    let(:offset) { rand.to_i }

    before do
      base_consumer.client = client

      allow(client).to receive(:mark_as_consumed!)

      base_consumer.send(:mark_as_consumed!, message)
    end

    it 'expect to proxy pass to client' do
      expect(client).to have_received(:mark_as_consumed!).with(message)
    end

    it 'epxect to increase seek_offset' do
      expect(base_consumer.instance_variable_get(:@seek_offset)).to eq(offset + 1)
    end
  end
end
