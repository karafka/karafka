require 'spec_helper'

RSpec.describe Karafka::Status do
  subject { described_class.instance }

  it 'by default should be in initialized state because it is bootstraped' do
    expect(subject.running?).to eq false
    expect(subject.stopped?).to eq false
    expect(subject.initializing?).to eq true
  end

  describe 'running?' do
    context 'when status is not set to running' do
      before do
        subject.instance_variable_set(:'@status', rand)
      end

      it { expect(subject.running?).to eq false }
    end

    context 'when status is set to running' do
      before do
        subject.instance_variable_set(:'@status', :running)
      end

      it { expect(subject.running?).to eq true }
    end
  end

  describe 'run!' do
    context 'when we set it to run' do
      before { subject.run! }

      it { expect(subject.running?).to eq true }
      it { expect(subject.initializing?).to eq false }
      it { expect(subject.stopped?).to eq false }
    end
  end

  describe 'stopped?' do
    context 'when status is not set to stopped' do
      before do
        subject.instance_variable_set(:'@status', rand)
      end

      it { expect(subject.stopped?).to eq false }
    end

    context 'when status is set to stopped' do
      before do
        subject.instance_variable_set(:'@status', :stopped)
      end

      it { expect(subject.stopped?).to eq true }
    end
  end

  describe 'stop!' do
    context 'when we set it to stop' do
      before do
        subject.run!
        subject.stop!
      end

      it { expect(subject.running?).to eq false }
      it { expect(subject.initializing?).to eq false }
      it { expect(subject.stopped?).to eq true }
    end
  end

  describe 'initializing?' do
    context 'when status is not set to initializing' do
      before do
        subject.instance_variable_set(:'@status', rand)
      end

      it { expect(subject.initializing?).to eq false }
    end

    context 'when status is set to initializing' do
      before do
        subject.instance_variable_set(:'@status', :initializing)
      end

      it { expect(subject.initializing?).to eq true }
    end
  end

  describe 'initialize!' do
    context 'when we set it to initialize' do
      before do
        subject.initialize!
      end

      it { expect(subject.running?).to eq false }
      it { expect(subject.initializing?).to eq true }
      it { expect(subject.stopped?).to eq false }
    end
  end
end
