# frozen_string_literal: true

RSpec.describe Karafka::BaseController do
  subject(:base_controller) { working_class.new }

  let(:topic_name) { "topic#{rand}" }
  let(:backend) { :inline }
  let(:responder_class) { nil }
  let(:consumer_group) { Karafka::Routing::ConsumerGroup.new(rand.to_s) }
  let(:topic) do
    topic = Karafka::Routing::Topic.new(topic_name, consumer_group)
    topic.controller = Class.new(described_class)
    topic.backend = backend
    topic.responder = responder_class
    topic
  end
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      include Karafka::Backends::Inline
      include Karafka::Controllers::Responders

      def consume
        self
      end
    end
  end

  before { working_class.topic = topic }

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(described_class) }

    it { expect { base_controller.send(:consume) }.to raise_error NotImplementedError }
  end

  describe '#call' do
    it 'just consumes' do
      expect(base_controller).to receive(:consume)

      base_controller.call
    end
  end

  describe '#params_batch=' do
    let(:messages) { [rand] }
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }
    let(:topic_parser) { Karafka::Parsers::Json }
    let(:p_args) { [messages, topic_parser] }

    before do
      working_class.topic = instance_double(
        Karafka::Routing::Topic,
        parser: topic_parser,
        backend: :inline,
        batch_consuming: false,
        responder: false
      )
    end

    it 'expect to build params batch using messages and parser' do
      expect(Karafka::Params::ParamsBatch).to receive(:new).with(*p_args).and_return(params_batch)
      base_controller.params_batch = messages
      expect(base_controller.send(:params_batch)).to eq params_batch
    end
  end

  describe '#params_batch' do
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }

    before { base_controller.instance_variable_set(:@params_batch, params_batch) }

    it { expect(base_controller.send(:params_batch)).to eq params_batch }
  end

  describe '#respond_with' do
    let(:responder_class) { Karafka::BaseResponder }
    let(:responder) { instance_double(responder_class) }
    let(:data) { [rand, rand] }

    it 'expect to use responder to respond with provided data' do
      expect(responder_class).to receive(:new).and_return(responder)
      expect(responder).to receive(:call).with(data)
      base_controller.send(:respond_with, data)
    end
  end

  describe '#consumer' do
    let(:consumer) { instance_double(Karafka::Connection::Consumer) }

    before { Karafka::Persistence::Consumer.write(consumer) }

    it 'expect to return current persisted consumer' do
      expect(base_controller.send(:consumer)).to eq consumer
    end
  end
end
