require 'spec_helper'

RSpec.describe Karafka::BaseWorker do
  subject(:base_worker) { described_class.new }

  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      def perform
        self
      end

      def after_failure
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

    it 'sets params and perform controller action' do
      expect(controller_instance)
        .to receive(:perform)

      base_worker.perform(*args)

      expect(base_worker.params).to eq args.last
    end

    it 'sets topic and perform controller action' do
      expect(controller_instance)
        .to receive(:perform)

      base_worker.perform(*args)

      expect(base_worker.topic).to eq args.first
    end
  end

  describe '#after_failure' do
    before do
      expect(base_worker)
        .to receive(:controller)
        .and_return(controller_instance)
        .at_least(:once)
    end

    context 'when after_failure method is not defined on the controller' do
      it 'does nothing' do
        expect(controller_instance)
          .to receive(:respond_to?)
          .and_return(false)
          .at_least(:once)

        expect(controller_instance)
          .not_to receive(:after_failure)

        base_worker.after_failure(*args)
      end
    end

    context 'when after_failure method is defined on the controller' do
      it 'executes it' do
        expect(controller_instance)
          .to receive(:respond_to?)
          .and_return(true)
          .at_least(:once)

        expect(controller_instance)
          .to receive(:after_failure)

        base_worker.after_failure(*args)
      end
    end
  end

  describe '#controller' do
    let(:topic) { rand.to_s }
    let(:router) { Karafka::Routing::Router.new(topic) }
    let(:interchanger) { double }
    let(:params) { double }
    let(:interchanged_params) { double }

    before do
      router
      base_worker.params = params
    end

    it 'expect to use router to pick controller, assign params and return' do
      expect(base_worker).to receive(:topic) { topic }
      expect(Karafka::Routing::Router).to receive(:new).with(topic).and_return(router)
      expect(router).to receive(:build).and_return(controller_instance)
      expect(controller_instance).to receive(:interchanger).and_return(interchanger)
      expect(interchanger).to receive(:parse).with(params).and_return(interchanged_params)
      expect(controller_instance).to receive(:params=).with(interchanged_params)

      expect(base_worker.send(:controller)).to eq controller_instance
    end
  end
end
