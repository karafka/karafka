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

  let(:args) { [controller.to_s, rand] }

  describe '#execute' do
    before do
      expect(subject)
        .to receive(:controller)
        .and_return(controller)
    end

    it 'should set params and perform controller action' do
      expect(controller)
        .to receive(:perform)

      subject.execute(*args)

      expect(subject.params).to eq args.last
    end

    it 'should set controller_class_name and perform controller action' do
      expect(controller)
        .to receive(:perform)

      subject.execute(*args)

      expect(subject.controller_class_name).to eq args.first
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
    before do
      NamedController = controller
    end

    let(:params) { double }
    let(:interchanged_parse_params) { double }

    it 'should get controller based on controller_class_name and assign params via interchanger' do
      expect(subject)
        .to receive(:controller_class_name)
        .and_return(NamedController.to_s)

      expect(subject)
        .to receive(:params)
        .and_return(params)

      expect(NamedController.interchanger)
        .to receive(:parse)
        .with(params)
        .and_return(interchanged_parse_params)

      expect_any_instance_of(controller)
        .to receive(:params=)
        .with(interchanged_parse_params)

      ctrl = subject.send(:controller)

      expect(ctrl).to be_a controller
    end
  end
end
