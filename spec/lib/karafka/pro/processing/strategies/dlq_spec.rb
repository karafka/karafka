# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) do
    %i[
      dead_letter_queue
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
