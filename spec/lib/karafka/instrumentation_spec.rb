# frozen_string_literal: true

RSpec.describe_current do
  subject(:instrumentation) { described_class }

  let(:waterdrop_instr) { ::WaterDrop::Instrumentation }

  describe '#statistics_callbacks' do
    it { expect(instrumentation.statistics_callbacks).to be_a(waterdrop_instr::CallbacksManager) }
    it { expect(instrumentation.statistics_callbacks).to eq(waterdrop_instr.statistics_callbacks) }
  end

  describe '#error_callbacks' do
    it { expect(instrumentation.error_callbacks).to be_a(waterdrop_instr::CallbacksManager) }
    it { expect(instrumentation.error_callbacks).to eq(waterdrop_instr.error_callbacks) }
  end

  it 'expect to have separate manager for each type of callbacks' do
    expect(instrumentation.statistics_callbacks).not_to eq(instrumentation.error_callbacks)
  end
end
