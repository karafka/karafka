# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { described_class.new }

  let(:executor) { build(:processing_executor) }

  describe '#consume' do
    it { expect(builder.consume(executor, [])).to be_a(Karafka::Processing::Jobs::Consume) }
  end

  describe '#revoked' do
    it { expect(builder.revoked(executor)).to be_a(Karafka::Processing::Jobs::Revoked) }
  end

  describe '#shutdown' do
    it { expect(builder.shutdown(executor)).to be_a(Karafka::Processing::Jobs::Shutdown) }
  end
end
