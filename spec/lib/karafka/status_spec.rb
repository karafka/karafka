require 'spec_helper'

RSpec.describe Karafka::Status do
  subject { described_class.instance }

  it 'by default should not be running' do
    expect(subject.running?).to eq false
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
    end
  end

  describe 'stop!' do
    context 'when we set it to stop' do
      before do
        subject.run!
        subject.stop!
      end

      it { expect(subject.running?).to eq false }
    end
  end
end
