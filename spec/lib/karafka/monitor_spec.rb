require 'spec_helper'

RSpec.describe Karafka::Monitor do
  subject { described_class.new }

  describe '#new' do
    context 'with default signals' do
      it 'should set DEFAULT_SIGNALS to @signals' do
        expect(subject.instance_variable_get('@signals'))
          .to eq described_class::DEFAULT_SIGNALS
      end
    end

    context 'with defined signals' do
      let(:signals) { [rand.to_s, rand.to_s] }
      it 'should set passed signals to @signals' do
        expect(described_class.new(signals).instance_variable_get('@signals'))
          .to eq signals
      end
    end

    it 'should set @terminated false' do
      expect(subject.instance_variable_get('@terminated')).to eq false
    end
  end

  describe '#catch_signals' do
    let(:block) { -> {} }
    it 'should trap signals, yield and reset signals' do
      expect(subject)
        .to receive(:trap_signals)

      expect(block)
        .to receive(:call)

      expect(subject)
        .to receive(:reset_signals)

      subject.send(:catch_signals, &block)
    end
  end

  describe '#trap_signals' do
    let(:signals) { [rand.to_s, rand.to_s] }
    before do
      subject.instance_variable_set('@signals', signals)
      signals.each do |s|
        expect(subject)
          .to receive(:trap)
          .and_yield

        expect(subject)
          .to receive(:log_error)
          .with(s)
      end
    end
    it 'should trap signals, log error and set terminated false' do
      subject.send(:trap_signals)
      expect(subject.instance_variable_get('@terminated')).to eq true
    end
  end

  describe '#log_error' do
    let(:signal) { rand.to_s }
    it 'should log error with signal code into Karafka logger' do
      expect(Thread)
        .to receive(:new)
        .and_yield

      expect(Karafka.logger)
        .to receive(:error)
        .with("Terminating with signal #{signal}")

      subject.send(:log_error, signal)
    end
  end

  describe '#reset_signals' do
    let(:signals) { [rand.to_s, rand.to_s] }
    before do
      subject.instance_variable_set('@signals', signals)
    end

    it 'should reset signals to default values' do
      signals.each do |s|
        expect(subject)
          .to receive(:trap)
          .with(s, :SIG_DFL)
      end
      subject.send(:reset_signals)
    end
  end
end
