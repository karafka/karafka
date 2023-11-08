# frozen_string_literal: true

RSpec.describe_current do
  subject(:runner) { described_class.new(interval: 500) { buffer << true } }

  let(:buffer) { [] }

  context 'when we run it for the first time' do
    it { expect { runner.call }.to change(buffer, :size).from(0).to(1) }
  end

  context 'when consecutive calls within time window' do
    before { runner.call }

    it { expect { 100.times { runner.call } }.not_to change(buffer, :size) }
  end

  context 'when running after reset' do
    before do
      runner.call
      runner.reset
    end

    it { expect { runner.call }.to change(buffer, :size).from(1).to(2) }
  end

  context 'when running after the window' do
    before do
      runner.call
      sleep(0.5)
    end

    it { expect { runner.call }.to change(buffer, :size).from(1).to(2) }
  end
end
