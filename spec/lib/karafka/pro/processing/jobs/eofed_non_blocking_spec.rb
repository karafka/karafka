# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  specify { expect(described_class.action).to eq(:eofed) }

  it { expect(job.non_blocking?).to be(true) }
  it { expect(described_class).to be < Karafka::Processing::Jobs::Eofed }
end
