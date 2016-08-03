require 'spec_helper'

RSpec.describe Karafka::App do
  subject(:app_class) { described_class }

  describe '#config' do
    let(:config) { double }

    it 'aliases to Config' do
      expect(Karafka::Setup::Config)
        .to receive(:config)
        .and_return(config)

      expect(app_class.config).to eq config
    end
  end

  describe '#routes' do
    let(:routes) { Karafka::Routing::Builder.instance }

    it 'returns routes builder' do
      expect(app_class.routes).to eq routes
    end
  end

  describe '#setup' do
    it 'delegates it to Config setup and set framework to initializing state' do
      expect(Karafka::Setup::Config)
        .to receive(:setup)
        .once

      expect(app_class)
        .to receive(:initialize!)

      app_class.setup
    end
  end

  describe 'Karafka delegations' do
    %i(
      root
      env
    ).each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(Karafka)
            .to receive(delegation)
            .and_return(return_value)

          expect(app_class.public_send(delegation)).to eq return_value
        end
      end
    end
  end

  describe 'Karafka::Status delegations' do
    %i(
      run!
      running?
      stop!
    ).each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(Karafka::Status.instance)
            .to receive(delegation)
            .and_return(return_value)

          expect(app_class.public_send(delegation)).to eq return_value
        end
      end
    end
  end
end
