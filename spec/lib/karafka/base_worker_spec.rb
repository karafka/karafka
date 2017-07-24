# frozen_string_literal: true

RSpec.describe Karafka::BaseWorker do
  subject(:base_worker) { described_class.new }

  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      def perform
        self
      end
    end
  end

  let(:controller_instance) { controller.new }

  let(:args) { [rand.to_s, rand] }

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
    let(:params) { double }
    let(:interchanged_params) { double }
    let(:topic) { instance_double(Karafka::Routing::Topic, interchanger: interchanger) }

    it 'expect to use router to pick controller, assign params and return' do
      expect(Karafka::Routing::Router).to receive(:build).with(topic_id).and_return(controller_instance)
      expect(controller_instance).to receive(:topic).and_return(topic)
      expect(interchanger).to receive(:parse).with(params).and_return(interchanged_params)
      expect(controller_instance).to receive(:params=).with(interchanged_params)

      expect(base_worker.send(:controller, topic_id, params)).to eq controller_instance
    end
  end
end
