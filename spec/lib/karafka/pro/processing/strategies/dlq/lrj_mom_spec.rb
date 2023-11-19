# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) do
    %i[
      dead_letter_queue
      long_running_job
      manual_offset_management
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
