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

      def perform
        self
      end
    end
  end

  before { working_class.topic = topic }

  describe '#perform' do
    let(:working_class) { ClassBuilder.inherit(described_class) }

    it { expect { base_controller.send(:perform) }.to raise_error NotImplementedError }
  end

  describe '#call' do
    context 'when there are no callbacks' do
      it 'just schedules' do
        expect(base_controller).to receive(:process)

        base_controller.call
      end
    end
  end

  describe '#params_batch=' do
    let(:messages) { [rand] }
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }
    let(:topic_parser) { Karafka::Parsers::Json }

    before do
      working_class.topic = instance_double(
        Karafka::Routing::Topic,
        parser: topic_parser,
        backend: :inline,
        batch_processing: false,
        responder: false
      )

      expect(Karafka::Params::ParamsBatch)
        .to receive(:new)
        .with(messages, topic_parser)
        .and_return(params_batch)
    end

    it 'expect to build params batch using messages and parser' do
      base_controller.params_batch = messages
      expect(base_controller.params_batch).to eq params_batch
    end
  end

  describe '#params_batch' do
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }

    before { base_controller.instance_variable_set(:@params_batch, params_batch) }

    it { expect(base_controller.params_batch).to eq params_batch }
  end

  describe '#respond_with' do
    let(:responder_class) { Karafka::BaseResponder }
    let(:responder) { instance_double(responder_class) }
    let(:data) { [rand, rand] }

    before do
      expect(responder_class)
        .to receive(:new).and_return(responder)
    end

    it 'expect to use responder to respond with provided data' do
      expect(responder).to receive(:call).with(data)
      base_controller.send(:respond_with, data)
    end
  end

  context 'when we have a block based after_received' do
    let(:backend) { :inline }

    context 'and it throws abort to halt' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          after_received do
            throw(:abort)
          end

          def perform
            self
          end
        end.new
      end

      it 'does not perform' do
        expect(base_controller).not_to receive(:perform)

        base_controller.call
      end
    end

    context 'and it does not throw abort to halt' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          include Karafka::Backends::Inline

          after_received do
            true
          end

          def perform
            self
          end
        end.new
      end

      let(:params) { double }

      it 'executes' do
        expect(base_controller).to receive(:process)
        base_controller.call
      end
    end
  end

  context 'when we have a method based after_received' do
    let(:backend) { :inline }

    context 'and it throws abort to halt' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          after_received :method

          def perform
            self
          end

          def method
            throw(:abort)
          end
        end.new
      end

      it 'does not perform' do
        expect(base_controller).not_to receive(:perform)

        base_controller.call
      end
    end

    context 'and it does not return false' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          include Karafka::Backends::Inline

          after_received :method

          def perform
            self
          end

          def method
            true
          end
        end.new
      end

      it 'schedules to a backend' do
        expect(base_controller).to receive(:process)

        base_controller.call
      end
    end
  end
end
