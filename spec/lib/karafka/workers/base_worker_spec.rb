require 'spec_helper'

RSpec.describe Karafka::Workers::BaseWorker do
  subject { described_class.new }

  before do
    # By default we don't set on base - on those that inherit only
    described_class.timeout = 1
  end

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

  let(:args) { [rand.to_s, rand] }

  describe '#perform' do
    before do
      expect(subject)
        .to receive(:controller)
        .and_return(controller)
    end

    it 'should set params and perform controller action' do
      expect(controller)
        .to receive(:perform)

      subject.perform(*args)

      expect(subject.params).to eq args.last
    end

    it 'should set topic and perform controller action' do
      expect(controller)
        .to receive(:perform)

      subject.perform(*args)

      expect(subject.topic).to eq args.first
    end
  end

  describe '#after_failure' do
    before do
      expect(subject)
        .to receive(:controller)
        .and_return(controller)
        .at_least(:once)
    end

    context 'when after_failure method is not defined on the controller' do
      it 'should do nothing' do
        expect(controller)
          .to receive(:respond_to?)
          .and_return(false)
          .at_least(:once)

        expect(controller)
          .to_not receive(:after_failure)

        subject.after_failure(*args)
      end
    end

    context 'when after_failure method is defined on the controller' do
      it 'should execute it' do
        expect(controller)
          .to receive(:respond_to?)
          .and_return(true)
          .at_least(:once)

        expect(controller)
          .to receive(:after_failure)

        subject.after_failure(*args)
      end
    end
  end

  describe '#controller' do
    let(:topic) { rand.to_s }
    let(:router) { Karafka::Routing::Router.new(topic) }
    let(:interchanger) { double }
    let(:params) { double }
    let(:interchanged_params) { double }
    let(:controller_instance) { controller.new }

    before do
      router
      subject.params = params
    end

    it 'expect to use router to pick controller, assign params and return' do
      expect(subject)
        .to receive(:topic) { topic }

      expect(Karafka::Routing::Router)
        .to receive(:new)
        .with(topic)
        .and_return(router)

      expect(router)
        .to receive(:build)
        .and_return(controller_instance)

      expect(controller_instance)
        .to receive(:interchanger)
        .and_return(interchanger)

      expect(interchanger)
        .to receive(:parse)
        .with(params)
        .and_return(interchanged_params)

      expect(controller_instance)
        .to receive(:params=)
        .with(interchanged_params)

      expect(subject.send(:controller)).to eq controller_instance
    end
  end
end
