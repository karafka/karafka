require 'spec_helper'

RSpec.describe Karafka::Workers::BaseWorker do
  subject { described_class.new }

  specify { expect(described_class).to be < SidekiqGlass::Worker }

  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end

      def after_failure
        self
      end
    end
  end

  describe '#execute' do
    let(:args) { [rand] }

    before do
      expect(subject)
        .to receive(:controller)
        .and_return(controller)
    end

    it 'should assign sidekiq args and perform controller action' do
      expect(controller)
        .to receive(:perform)

      subject.execute(*args)

      expect(subject.args).to eq args
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

        subject.after_failure
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

        subject.after_failure
      end
    end
  end

  describe '#params' do
    let(:params) { double }
    let(:arg) { double }
    let(:args) { [arg] }

    it 'should create karafka params based on the first (and only) argument' do
      expect(subject)
        .to receive(:args)
        .and_return(args)

      expect(Karafka::Params)
        .to receive(:new)
        .with(arg)
        .and_return(params)

      expect(subject.send(:params)).to eq params
      expect(subject.instance_variable_get(:'@params')).to eq params
    end
  end

  describe '#controller' do
    before do
      subject.instance_variable_set(:'@controller', controller)
    end

    context 'when controller is already built' do
      let(:controller) { double }

      it 'should return it and do nothing else' do
        expect(Karafka::Routing::Router)
          .not_to receive(:new)

        expect(Karafka::Connection::Message)
          .not_to receive(:new)

        expect(subject.send(:controller)).to eq controller
      end
    end

    context 'when controller is not yet built' do
      let(:controller) { nil }
      let(:message) { double }
      let(:router) { double }
      let(:routed_controller) { double }
      let(:topic) { double }
      let(:params) { { topic: topic, rand => rand } }

      it 'should create karafka message and build a controller' do
        expect(Karafka::Routing::Router)
          .to receive(:new)
          .with(message)
          .and_return(router)

        expect(Karafka::Connection::Message)
          .to receive(:new)
          .with(topic, params)
          .and_return(message)

        expect(subject)
          .to receive(:params)
          .and_return(params)
          .exactly(2).times

        expect(router)
          .to receive(:build)
          .and_return(routed_controller)

        expect(subject.send(:controller)).to eq routed_controller
      end
    end
  end
end
