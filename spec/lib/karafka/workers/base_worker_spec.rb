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

      expect(subject.params).to eq args.first
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

  describe '#controller' do
    before do
      NamedController = controller
    end

    let(:params) do
      {
        'controller' => 'NamedController'
      }
    end

    it 'should get the controller out of params and assign params as params' do
      expect(subject)
        .to receive(:params)
        .and_return(params)
        .exactly(2).times

      expect_any_instance_of(controller)
        .to receive(:params=)
        .with(params)

      ctrl = subject.send(:controller)

      expect(ctrl).to be_a controller
    end
  end
end
