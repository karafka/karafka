# frozen_string_literal: true

RSpec.describe Karafka::BaseConsumer do
  subject(:base_consumer) { working_class.new(topic) }

  let(:responder_class) { nil }
  let(:topic) do
    topic = build(:routing_topic)
    topic.responder = responder_class
    topic
  end
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      include Karafka::Backends::Inline
      include Karafka::Consumers::Responders

      def consume
        self
      end
    end
  end

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(described_class) }

    it { expect { base_consumer.send(:consume) }.to raise_error NotImplementedError }
  end

  describe '#call' do
    it 'just consumes' do
      expect(base_consumer).to receive(:consume)

      base_consumer.call
    end
  end

  describe '#params_batch' do
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }

    before { base_consumer.instance_variable_set(:@params_batch, params_batch) }

    it { expect(base_consumer.send(:params_batch)).to eq params_batch }
  end

  describe '#respond_with' do
    let(:responder_class) { Karafka::BaseResponder }
    let(:responder) { instance_double(responder_class) }
    let(:data) { [rand, rand] }

    it 'expect to use responder to respond with provided data' do
      expect(responder_class).to receive(:new).and_return(responder)
      expect(responder).to receive(:call).with(data)
      base_consumer.send(:respond_with, data)
    end
  end

  describe '#client' do
    let(:client) { instance_double(Karafka::Connection::Client) }

    before { Karafka::Persistence::Client.write(client) }

    it 'expect to return current persisted client' do
      expect(base_consumer.send(:client)).to eq client
    end
  end

  describe '#mark_as_consumed' do
    let(:client) { instance_double(Karafka::Connection::Client) }
    let(:params) { instance_double(Karafka::Params::Params) }

    before { Karafka::Persistence::Client.write(client) }

    it 'expect to proxy pass to client' do
      expect(client).to receive(:mark_as_consumed).with(params)
      base_consumer.send(:mark_as_consumed, params)
    end
  end

  describe '#mark_as_consumed!' do
    let(:client) { instance_double(Karafka::Connection::Client) }
    let(:params) { instance_double(Karafka::Params::Params) }

    before { Karafka::Persistence::Client.write(client) }

    it 'expect to proxy pass to client' do
      expect(client).to receive(:mark_as_consumed!).with(params)
      base_consumer.send(:mark_as_consumed!, params)
    end
  end

  describe 'trigger_heartbeat' do
    let(:client) { instance_double(Karafka::Connection::Client) }

    before { Karafka::Persistence::Client.write(client) }

    it 'expect to proxy pass to client' do
      expect(client).to receive(:trigger_heartbeat)
      base_consumer.send(:trigger_heartbeat)
    end
  end

  describe 'trigger_heartbeat!' do
    let(:client) { instance_double(Karafka::Connection::Client) }

    before { Karafka::Persistence::Client.write(client) }

    it 'expect to proxy pass to client' do
      expect(client).to receive(:trigger_heartbeat!)
      base_consumer.send(:trigger_heartbeat!)
    end
  end
end
