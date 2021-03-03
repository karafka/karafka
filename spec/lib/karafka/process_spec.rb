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
    before { allow(process).to receive(:trap_signal) }

    it 'traps signals and yield' do
      process.supervise

      described_class::HANDLED_SIGNALS.each do |signal|
        expect(process).to have_received(:trap_signal).with(signal)
      end
    end
  end

  describe '#trap_signal' do
    let(:signal) { rand.to_s }
    let(:callback) { double }

    before do
      process.instance_variable_set(:'@callbacks', signal => [callback])
      allow(process).to receive(:trap).with(signal).and_yield
    end

    it 'traps signals, log it and run callbacks if defined' do
      expect(process).to receive(:notice_signal).with(signal)
      expect(callback).to receive(:call)
      process.send(:trap_signal, signal)
    end
  end

  describe '#notice_signal' do
    let(:signal) { rand.to_s }
    let(:instrument_args) { ['process.notice_signal', { caller: process, signal: signal }] }

    it 'logs info with signal code into Karafka logger' do
      expect(Thread).to receive(:new).and_yield
      expect(Karafka.monitor).to receive(:instrument).with(*instrument_args)
      process.send(:notice_signal, signal)
    end
  end
end
