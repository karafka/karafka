# frozen_string_literal: true

RSpec.describe Karafka::Status do
  subject(:status_manager) { described_class.instance }

  it 'by default expect to be in initialized state because it is bootstraped' do
    expect(status_manager.running?).to eq false
    expect(status_manager.stopped?).to eq false
    expect(status_manager.initializing?).to eq true
  end

  describe 'running?' do
    context 'when status is not set to running' do
      before do
        status_manager.instance_variable_set(:'@status', rand)
      end

      it { expect(status_manager.running?).to eq false }
    end

    context 'when status is set to running' do
      before do
        status_manager.instance_variable_set(:'@status', :running)
      end

      it { expect(status_manager.running?).to eq true }
    end
  end

  describe 'run!' do
    context 'when we set it to run' do
      before { status_manager.run! }

      it { expect(status_manager.running?).to eq true }
      it { expect(status_manager.initializing?).to eq false }
      it { expect(status_manager.stopped?).to eq false }
    end
  end

  describe 'stopped?' do
    context 'when status is not set to stopped' do
      before do
        status_manager.instance_variable_set(:'@status', rand)
      end

      it { expect(status_manager.stopped?).to eq false }
    end

    context 'when status is set to stopped' do
      before do
        status_manager.instance_variable_set(:'@status', :stopped)
      end

      it { expect(status_manager.stopped?).to eq true }
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
      it { expect(status_manager.stopped?).to eq true }
    end
  end

  describe 'initializing?' do
    context 'when status is not set to initializing' do
      before do
        status_manager.instance_variable_set(:'@status', rand)
      end

      it { expect(status_manager.initializing?).to eq false }
    end

    context 'when status is set to initializing' do
      before do
        status_manager.instance_variable_set(:'@status', :initializing)
      end

      it { expect(status_manager.initializing?).to eq true }
    end
  end

  describe 'initialize!' do
    context 'when we set it to initialize' do
      before do
        status_manager.initialize!
      end

      it { expect(status_manager.running?).to eq false }
      it { expect(status_manager.initializing?).to eq true }
      it { expect(status_manager.stopped?).to eq false }
    end
  end
end
