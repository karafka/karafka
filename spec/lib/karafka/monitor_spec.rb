require 'spec_helper'

RSpec.describe Karafka::Monitor do
  subject { described_class.instance }

  described_class::HANDLED_SIGNALS.each do |signal|
    let(:callback) { -> {} }

    describe "on_#{signal.to_s.downcase}" do
      it 'should assign given callback to appropriate signal key' do
        subject.send(:"on_#{signal.to_s.downcase}", &callback)
        expect(subject.instance_variable_get(:@callbacks)[signal]).to include callback
      end
    end
  end

  describe '#supervise' do
    let(:block) { -> {} }

    it 'should trap signals and yield' do
      described_class::HANDLED_SIGNALS.each do |signal|
        expect(subject)
          .to receive(:trap_signal)
          .with(signal)
      end

      expect(block)
        .to receive(:call)

      subject.send(:supervise, &block)
    end
  end

  describe '#trap_signal' do
    let(:signal) { rand.to_s }
    let(:callback) { double }

    before do
      subject.instance_variable_set(:'@callbacks', signal => [callback])

      expect(subject)
        .to receive(:trap)
        .with(signal)
        .and_yield
    end

    it 'should trap signals, log it and run callbacks if defined' do
      expect(subject)
        .to receive(:log_signal)
        .with(signal)

      expect(callback)
        .to receive(:call)

      subject.send(:trap_signal, signal)
    end
  end

  describe '#log_signal' do
    let(:signal) { rand.to_s }
    it 'should log info with signal code into Karafka logger' do
      expect(Thread)
        .to receive(:new)
        .and_yield

      expect(Karafka.logger)
        .to receive(:info)
        .with("Received system signal #{signal}")

      subject.send(:log_signal, signal)
    end
  end
end
