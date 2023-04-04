# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) do
    %i[
      long_running_job
      throttling
      virtual_partitions
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
