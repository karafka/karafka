# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) do
    %i[
      manual_offset_management
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
