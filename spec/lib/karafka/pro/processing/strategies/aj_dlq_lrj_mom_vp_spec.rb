# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) do
    %i[
      active_job
      long_running_job
      manual_offset_management
      dead_letter_queue
      virtual_partitions
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
