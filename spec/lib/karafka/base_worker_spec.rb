# frozen_string_literal: true

RSpec.describe Karafka::BaseWorker do
  subject(:base_worker) { described_class.new }

  let(:controller_instance) { controller.new }
  let(:args) { [rand.to_s, rand] }
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      def perform
        self
      end
    end
  end

  describe '#perform' do
    before do
      expect(base_worker)
        .to receive(:controller)
        .and_return(controller_instance)
        .at_least(:once)
    end

    it 'performs controller action' do
      expect(controller_instance)
        .to receive(:perform)

      expect { base_worker.perform(*args) }.not_to raise_error
    end
  end

  describe '#controller' do
    let(:topic_id) { rand.to_s }
    let(:interchanger) { double }
    let(:params_batch) { double }
    let(:interchanged_params) { double }
    let(:topic) do
      instance_double(
        Karafka::Routing::Topic,
        interchanger: interchanger,
        controller: controller,
        backend: :sidekiq,
        batch_processing: false,
        responder: nil,
        parser: nil
      )
    end

    before do
      controller.topic = topic

      expect(Karafka::Routing::Router)
        .to receive(:find)
        .with(topic_id)
        .and_return(topic)

      expect(controller)
        .to receive(:new)
        .and_return(controller_instance)
    end

    it 'expect to use router to pick controller, assign params_batch and return' do
      expect(interchanger).to receive(:parse).with(params_batch).and_return(interchanged_params)
      expect(controller_instance).to receive(:params_batch=).with(interchanged_params)
      expect(base_worker.send(:controller, topic_id, params_batch)).to eq controller_instance
    end
  end
end
