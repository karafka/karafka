# frozen_string_literal: true

RSpec.describe Karafka::BaseController do
  subject(:base_controller) { working_class.new }

  let(:topic_name) { "topic#{rand}" }
  let(:inline_mode) { false }
  let(:responder_class) { nil }
  let(:interchanger) { nil }
  let(:worker) { nil }
  let(:consumer_group) { Karafka::Routing::ConsumerGroup.new(rand.to_s) }
  let(:topic) do
    topic = Karafka::Routing::Topic.new(topic_name, consumer_group)
    topic.controller = Class.new(described_class)
    topic.inline_mode = inline_mode
    topic.responder = responder_class
    topic.interchanger = interchanger
    topic.worker = worker
    topic
  end
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      def perform
        self
      end
    end
  end

  before { base_controller.topic = topic }

  describe '#perform' do
    context 'when perform method is defined' do
      it { expect { base_controller.perform }.not_to raise_error }
    end

    context 'when perform method is not defined' do
      let(:working_class) { ClassBuilder.inherit(described_class) }

      it { expect { base_controller.perform }.to raise_error NotImplementedError }
    end
  end

  describe '#schedule' do
    context 'when there are no callbacks' do
      context 'and we dont want to perform inline' do
        let(:inline_mode) { false }

        it 'just schedules via perform_async' do
          expect(base_controller).to receive(:perform_async)

          base_controller.schedule
        end
      end

      context 'and we want to perform inline' do
        let(:inline_mode) { true }

        it 'just expect to run with perform_inline' do
          expect(base_controller).to receive(:perform_inline)

          base_controller.schedule
        end
      end
    end
  end

  describe '#params_batch=' do
    let(:messages) { [rand] }
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }
    let(:topic_parser) { Karafka::Parsers::Json }

    before do
      base_controller.topic = instance_double(Karafka::Routing::Topic, parser: topic_parser)
    end

    it 'expect to build params batch using messages and parser' do
      expect(Karafka::Params::ParamsBatch)
        .to receive(:new).with(messages, topic_parser)
        .and_return(params_batch)

      base_controller.params_batch = messages
      expect(base_controller.params_batch).to eq params_batch
    end
  end

  describe '#params_batch' do
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch) }

    before { base_controller.instance_variable_set(:@params_batch, params_batch) }

    it { expect(base_controller.params_batch).to eq params_batch }
  end

  describe '#params' do
    let(:params) { Karafka::Params::Params.build({}, nil) }

    before { base_controller.instance_variable_set(:@params_batch, [params]) }

    context 'for batch_processing controllers' do
      before do
        base_controller.topic = instance_double(Karafka::Routing::Topic, batch_processing: true)
      end

      it 'retrieves params data' do
        expected_error = Karafka::Errors::ParamsMethodUnavailable
        expect { base_controller.send(:params) }.to raise_error(expected_error)
      end
    end

    context 'for non batch_processing controllers' do
      it 'retrieves params data' do
        expect(base_controller.send(:params)).to eq params
      end
    end
  end

  describe '#respond_with' do
    context 'when there is no responder for a given controller' do
      let(:error) { Karafka::Errors::ResponderMissing }

      it { expect { base_controller.send(:respond_with, {}) }.to raise_error(error) }
    end

    context 'when there is responder for a given controller' do
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
  end

  describe '#perform_inline' do
    it 'expect to perform' do
      expect(base_controller).to receive(:perform)
      base_controller.send(:perform_inline)
    end
  end

  describe '#perform_async' do
    let(:params_batch) { instance_double(Karafka::Params::ParamsBatch, to_a: [double]) }
    let(:interchanged_load_params) { double }
    let(:worker) { double }

    it 'enqueue perform function' do
      base_controller.instance_variable_set :@params_batch, params_batch
      expect(topic.interchanger).to receive(:load)
        .with(params_batch.to_a).and_return(interchanged_load_params)
      expect(worker).to receive(:perform_async)
        .with(topic.id, interchanged_load_params)
      base_controller.send :perform_async
    end
  end

  context 'when we have a block based before_enqueue' do
    context 'and it throws abort to halt' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          before_enqueue do
            throw(:abort)
          end

          def perform
            self
          end
        end.new
      end

      it 'does not enqueue' do
        expect(base_controller).not_to receive(:enqueue)

        base_controller.schedule
      end
    end

    context 'and it does not throw abort to halt' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          before_enqueue do
            true
          end

          def perform
            self
          end
        end.new
      end

      let(:params) { double }

      it 'executes perform_async' do
        expect(base_controller).to receive(:perform_async)

        base_controller.schedule
      end
    end
  end

  context 'when we have a method based before_enqueue' do
    context 'and it throws abort to halt' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          before_enqueue :method

          def perform
            self
          end

          def method
            throw(:abort)
          end
        end.new
      end

      it 'does not enqueue' do
        expect(base_controller).not_to receive(:enqueue)

        base_controller.schedule
      end
    end

    context 'and it does not return false' do
      subject(:base_controller) do
        ClassBuilder.inherit(described_class) do
          before_enqueue :method

          def perform
            self
          end

          def method
            true
          end
        end.new
      end

      it 'enqueues with perform_async' do
        expect(base_controller).to receive(:perform_async)

        base_controller.schedule
      end
    end
  end
end
