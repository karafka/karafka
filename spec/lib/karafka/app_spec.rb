require 'spec_helper'

RSpec.describe Karafka::App do
  subject { described_class }

  describe '#run' do
    it 'should start consuming' do
      expect_any_instance_of(Karafka::Connection::Consumer)
        .to receive(:call)

      subject.run
    end
  end

  describe '#logger=' do
    let(:logger) { double }

    it 'should assign logger' do
      subject.logger = logger
      expect(subject.instance_variable_get(:'@logger')).to eq logger
    end
  end

  describe '#logger' do
    context 'when logger is already set' do
      let(:logger) { double }

      before do
        subject.instance_variable_set(:'@logger', logger)
      end

      it 'should use logger that was defined' do
        expect(subject.logger).to eq logger
      end
    end

    context 'when logger is not provided' do
      before do
        subject.instance_variable_set(:'@logger', nil)
      end

      it 'should use a default logger' do
        expect(subject.logger).to be_a Karafka::Logger
      end
    end
  end

  describe '#config' do
    let(:config) { double }

    it 'should alias to Config' do
      expect(Karafka::Config)
        .to receive(:config)
        .and_return(config)

      expect(subject.config).to eq config
    end
  end

  describe '#setup' do
    it 'should delegate it to Config setup' do
      expect(Karafka::Config)
        .to receive(:setup)
        .once

      subject.setup
    end
  end
end
