require 'spec_helper'

RSpec.describe Karafka::App do
  subject { described_class }

  describe '#run' do
    let(:runner) { Karafka::Runner.new }

    it 'runs in supervision, start consuming and sleep' do
      expect(subject)
        .to receive(:sleep)

      expect(subject)
        .to receive(:run!)

      expect(Karafka::Runner)
        .to receive(:new)
        .and_return(runner)

      expect(runner)
        .to receive(:run)

      expect(Karafka::Process.instance)
        .to receive(:supervise)
        .and_yield

      expect(Karafka::Process.instance)
        .to receive(:on_sigint)

      expect(Karafka::Process.instance)
        .to receive(:on_sigquit)

      subject.run
    end

    it 'defines a proper action for sigint' do
      expect(Karafka::Process.instance)
        .to receive(:supervise)

      expect(Karafka::Process.instance)
        .to receive(:on_sigint)
        .and_yield

      expect(Karafka::Process.instance)
        .to receive(:on_sigquit)

      expect(subject)
        .to receive(:stop!)

      expect(subject)
        .to receive(:exit)

      subject.run
    end

    it 'defines a proper action for sigquit' do
      expect(Karafka::Process.instance)
        .to receive(:supervise)

      expect(Karafka::Process.instance)
        .to receive(:on_sigint)

      expect(Karafka::Process.instance)
        .to receive(:on_sigquit)
        .and_yield

      expect(subject)
        .to receive(:stop!)

      expect(subject)
        .to receive(:exit)

      subject.run
    end
  end

  describe '#config' do
    let(:config) { double }

    it 'aliases to Config' do
      expect(Karafka::Setup::Config)
        .to receive(:config)
        .and_return(config)

      expect(subject.config).to eq config
    end
  end

  describe '#routes' do
    let(:routes) { Karafka::Routing::Builder.instance }

    it 'returns routes builder' do
      expect(subject.routes).to eq routes
    end
  end

  describe '#setup' do
    it 'delegates it to Config setup and set framework to initializing state' do
      expect(Karafka::Setup::Config)
        .to receive(:setup)
        .once

      expect(subject)
        .to receive(:initialize!)

      subject.setup
    end
  end

  describe '#process' do
    it { expect(subject.send(:process)).to be_a Karafka::Process }
  end

  describe 'Karafka delegations' do
    %i( root env ).each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "should delegate #{delegation} method to Karafka module" do
          expect(Karafka)
            .to receive(delegation)
            .and_return(return_value)

          expect(subject.public_send(delegation)).to eq return_value
        end
      end
    end
  end

  describe 'Karafka::Status delegations' do
    %i( run! running? stop! ).each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "should delegate #{delegation} method to Karafka module" do
          expect(Karafka::Status.instance)
            .to receive(delegation)
            .and_return(return_value)

          expect(subject.public_send(delegation)).to eq return_value
        end
      end
    end
  end
end
