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

  context 'when using call! method' do
    context 'when it is for the first time' do
      it { expect { runner.call! }.to change(buffer, :size).from(0).to(1) }
    end

    context 'when called consecutively within time window' do
      it 'executes the block each time' do
        expect { 3.times { runner.call! } }.to change(buffer, :size).from(0).to(3)
      end
    end

    context 'when called after a regular call within time window' do
      before { runner.call }

      it 'executes the block bypassing interval restriction' do
        expect { runner.call! }.to change(buffer, :size).from(1).to(2)
      end
    end

    context 'when regular call is made after call!' do
      before { runner.call! }

      it 'does not execute due to interval restriction' do
        expect { runner.call }.not_to change(buffer, :size)
      end
    end

    context 'when call! is used after regular call and before interval expires' do
      before do
        runner.call
        # Ensure we're still within the interval window
        sleep(0.1) # Less than the 500ms interval
      end

      it 'executes immediately bypassing the interval' do
        expect { runner.call! }.to change(buffer, :size).from(1).to(2)
      end
    end
  end
end
