require 'spec_helper'

RSpec.describe Karafka::Process do
  subject { described_class.instance }

  described_class::HANDLED_SIGNALS.each do |signal|
    let(:callback) { -> {} }

    describe "on_#{signal.to_s.downcase}" do
      it 'assigns given callback to appropriate signal key' do
        subject.send(:"on_#{signal.to_s.downcase}", &callback)
        expect(subject.instance_variable_get(:@callbacks)[signal]).to include callback
      end
    end
  end

  describe '#supervise' do
    it 'traps signals and yield' do
      described_class::HANDLED_SIGNALS.each do |signal|
        expect(subject)
          .to receive(:trap_signal)
          .with(signal)
      end

      expect { |block| subject.send(:supervise, &block) }.to yield_control
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

    it 'traps signals, log it and run callbacks if defined' do
      expect(subject)
        .to receive(:notice_signal)
        .with(signal)

      expect(callback)
        .to receive(:call)

      subject.send(:trap_signal, signal)
    end
  end

  describe '#notice_signal' do
    let(:signal) { rand.to_s }
    it 'logs info with signal code into Karafka logger' do
      expect(Thread)
        .to receive(:new)
        .and_yield

      expect(Karafka.monitor)
        .to receive(:notice)
        .with(described_class, signal: signal)

      subject.send(:notice_signal, signal)
    end
  end
end
