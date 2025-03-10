# frozen_string_literal: true

RSpec.describe_current do
  subject(:process) { described_class.new }

  before { process.instance_variable_set(:@callbacks, Hash.new { |hsh, key| hsh[key] = [] }) }

  described_class::HANDLED_SIGNALS.each do |signal|
    let(:callback) { -> {} }

    describe "on_#{signal.to_s.downcase}" do
      it 'assigns given callback to appropriate signal key' do
        process.send(:"on_#{signal.to_s.downcase}", &callback)
        expect(process.instance_variable_get(:@callbacks)[signal]).to include callback
      end
    end
  end

  describe '#supervise' do
    before do
      allow(process).to receive(:trap_signal)

      described_class::HANDLED_SIGNALS.each do |signal|
        process.public_send(:"on_#{signal.to_s.downcase}", &-> {})
      end
    end

    it 'traps signals and yield' do
      process.supervise

      described_class::HANDLED_SIGNALS.each do |signal|
        expect(process).to have_received(:trap_signal).with(signal)
      end
    end
  end

  describe '#on_any_active' do
    before { allow(process).to receive(:trap_signal) }

    context 'when no callbacks registered' do
      it 'expect not to bind to anything' do
        process.on_any_active {}
        process.supervise
        expect(process).not_to have_received(:trap_signal)
      end
    end

    context 'when callbacks were registered' do
      before do
        process.on_sigint {}
      end

      it 'expect to bind' do
        process.on_any_active {}
        process.supervise
        expect(process).to have_received(:trap_signal).once
      end
    end
  end

  describe '#supervised?' do
    context 'when we did not install the trap hooks yet' do
      it { expect(process.supervised?).to be(false) }
    end

    context 'when we did install trap hooks' do
      before do
        allow(process).to receive(:trap_signal)
        process.supervise
      end

      it { expect(process.supervised?).to be(true) }
    end
  end

  describe '#trap_signal' do
    let(:signal) { rand.to_s }
    let(:callback) { double }

    before do
      process.instance_variable_set(:'@callbacks', signal => [callback])
      allow(::Signal).to receive(:trap).with(signal).and_yield
    end

    it 'traps signals, log it and run callbacks if defined' do
      expect(process).to receive(:notice_signal).with(signal)
      expect(callback).to receive(:call)
      process.send(:trap_signal, signal)
      sleep(1)
    end
  end

  describe '#notice_signal' do
    let(:signal) { rand.to_s }
    let(:instrument_args) { ['process.notice_signal', { caller: process, signal: signal }] }

    it 'logs info with signal code into Karafka logger' do
      expect(Karafka.monitor).to receive(:instrument).with(*instrument_args)
      process.send(:notice_signal, signal)
      sleep(1)
    end
  end
end
