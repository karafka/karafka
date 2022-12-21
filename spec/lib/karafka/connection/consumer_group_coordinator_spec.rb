# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(2) }

  it { expect(coordinator.shutdown?).to eq(false) }

  context 'when we finish some of the work' do
    before { coordinator.finish_work(1) }

    it { expect(coordinator.shutdown?).to eq(false) }
    it { expect(coordinator.finished?).to eq(false) }
  end

  context 'when we finish enough work and can get the lock' do
    before { 2.times { |i| coordinator.finish_work(i) } }

    after { coordinator.unlock }

    it { expect(coordinator.shutdown?).to eq(true) }
    it { expect(coordinator.finished?).to eq(true) }
  end
end
