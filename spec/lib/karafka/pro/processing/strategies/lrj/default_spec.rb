# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) { %i[long_running_job] }

  it { expect(described_class::FEATURES).to eq(combination) }
end
