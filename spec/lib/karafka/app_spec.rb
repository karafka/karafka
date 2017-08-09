# frozen_string_literal: true

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

  describe '#consumer_groups' do
    let(:builder) { Karafka::Routing::Builder.instance }

    it 'returns consumer_groups builder' do
      expect(app_class.consumer_groups).to eq builder
    end
  end

  describe '#setup' do
    it 'delegates it to Config setup and set framework to initializing state' do
      expect(Karafka::Setup::Config).to receive(:setup).once

      app_class.setup
    end
  end

  describe '#boot!' do
    let(:config) { double }

    it 'expect to run setup_components' do
      expect(Karafka::Setup::Config).to receive(:validate!).once
      expect(Karafka::Setup::Config).to receive(:setup_components)

      app_class.boot!
    end
  end

  describe 'Karafka delegations' do
    %i[
      root
      env
    ].each do |delegation|
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
    %i[
      run!
      running?
      stop!
    ].each do |delegation|
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
