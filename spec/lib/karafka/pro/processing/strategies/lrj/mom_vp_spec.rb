# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:combination) do
    %i[
      long_running_job
      manual_offset_management
      virtual_partitions
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
