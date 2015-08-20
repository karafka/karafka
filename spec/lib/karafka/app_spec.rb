require 'spec_helper'

RSpec.describe Karafka::App do
  subject { described_class }

  before do
    @logger = described_class.logger
  end

  after do
    described_class.logger = @logger
  end

  describe '#run' do
    it 'should start consuming' do
      expect_any_instance_of(Karafka::Runner)
        .to receive(:run)

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
      let(:logger) { double }

      before do
        subject.instance_variable_set(:'@logger', nil)
      end

      it 'should build a default logger' do
        expect(Karafka::Logger)
          .to receive(:build)
          .and_return(logger)

        expect(subject.logger).to eq logger
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
    it 'should delegate it to Config setup and execute after_setup' do
      expect(Karafka::Config)
        .to receive(:setup)
        .once

      expect(subject)
        .to receive(:after_setup)

      subject.setup
    end
  end

  describe '#after_setup' do
    let(:worker_timeout) { rand }
    let(:config) { double(worker_timeout: worker_timeout) }

    it 'should setup a workers timeout' do
      expect(Karafka::Worker)
        .to receive(:timeout=)
        .with(worker_timeout)

      expect(subject)
        .to receive(:config)
        .and_return(config)

      subject.send(:after_setup)
    end
  end

  describe '#root' do
    let(:root) { double }

    it 'should use Karafka.root' do
      expect(Karafka)
        .to receive(:root)
        .and_return(root)

      expect(subject.root).to eq root
    end
  end
end
