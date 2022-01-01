# frozen_string_literal: true

RSpec.describe_current do
  subject(:status_manager) { described_class.new }

  let(:status) { rand }

  before { status_manager.instance_variable_set(:'@status', status) }

  context 'when we start with a default state' do
    it { expect(status_manager.initialized?).to eq false }
    it { expect(status_manager.running?).to eq false }
    it { expect(status_manager.stopping?).to eq false }
    it { expect(status_manager.stopped?).to eq false }
    it { expect(status_manager.initializing?).to eq false }
  end

  describe 'running?' do
    context 'when status is not set to running' do
      it { expect(status_manager.running?).to eq false }
    end

    context 'when status is set to running' do
      let(:status) { :running }

      it { expect(status_manager.initialized?).to eq false }
      it { expect(status_manager.running?).to eq true }
    end
  end

  describe 'run!' do
    context 'when we set it to run' do
      before { status_manager.run! }

      it { expect(status_manager.running?).to eq true }
      it { expect(status_manager.initializing?).to eq false }
      it { expect(status_manager.initialized?).to eq false }
      it { expect(status_manager.stopping?).to eq false }
      it { expect(status_manager.stopped?).to eq false }
    end
  end

  describe 'stopping?' do
    context 'when status is not set to stopping' do
      before do
        status_manager.instance_variable_set(:'@status', rand)
      end

      it { expect(status_manager.initialized?).to eq false }
      it { expect(status_manager.stopping?).to eq false }
      it { expect(status_manager.stopped?).to eq false }
    end

    context 'when status is set to stopping' do
      before do
        status_manager.instance_variable_set(:'@status', :stopping)
      end

      it { expect(status_manager.initialized?).to eq false }
      it { expect(status_manager.stopping?).to eq true }
      it { expect(status_manager.stopped?).to eq false }
    end
  end

  describe 'stop!' do
    context 'when we set it to stop' do
      before do
        status_manager.run!
        status_manager.stop!
      end

      it { expect(status_manager.running?).to eq false }
      it { expect(status_manager.initializing?).to eq false }
      it { expect(status_manager.initialized?).to eq false }
      it { expect(status_manager.stopping?).to eq true }
      it { expect(status_manager.stopped?).to eq false }
    end
  end

  describe 'stopped!' do
    context 'when we set it to stopped' do
      before do
        status_manager.run!
        status_manager.stop!
        status_manager.stopped!
      end

      it { expect(status_manager.running?).to eq false }
      it { expect(status_manager.initializing?).to eq false }
      it { expect(status_manager.initialized?).to eq false }
      it { expect(status_manager.stopping?).to eq false }
      it { expect(status_manager.stopped?).to eq true }
    end
  end

  describe 'initializing?' do
    context 'when status is not set to initializing' do
      it { expect(status_manager.initializing?).to eq false }
    end

    context 'when status is set to initializing' do
      let(:status) { :initializing }

      it { expect(status_manager.initializing?).to eq true }
      it { expect(status_manager.initialized?).to eq false }
    end
  end

  describe 'initialize!' do
    context 'when we set it to initialize' do
      before do
        status_manager.initialize!
      end

      it { expect(status_manager.running?).to eq false }
      it { expect(status_manager.initializing?).to eq true }
      it { expect(status_manager.stopping?).to eq false }
    end
  end

  describe 'initialized!' do
    context 'when we set it to initialized' do
      before do
        status_manager.initialized!
      end

      it { expect(status_manager.initialized?).to eq true }
      it { expect(status_manager.running?).to eq false }
      it { expect(status_manager.initializing?).to eq false }
      it { expect(status_manager.stopping?).to eq false }
    end
  end
end
