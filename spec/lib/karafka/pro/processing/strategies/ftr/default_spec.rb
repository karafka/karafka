# frozen_string_literal: true

RSpec.describe_current do
  it { expect(described_class::FEATURES).to eq(%i[filtering]) }
end
