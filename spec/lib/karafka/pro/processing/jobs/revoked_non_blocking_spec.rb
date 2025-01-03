# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  specify { expect(described_class.action).to eq(:revoked) }

  it { expect(job.non_blocking?).to eq(true) }
  it { expect(described_class).to be < ::Karafka::Processing::Jobs::Revoked }
end
