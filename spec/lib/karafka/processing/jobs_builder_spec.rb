# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { described_class.new }

  let(:executor) { build(:processing_executor) }

  describe '#consume' do
    it do
      job = builder.consume(executor, [])
      expect(job).to be_a(Karafka::Processing::Jobs::Consume)
    end
  end

  describe '#eofed' do
    it do
      job = builder.eofed(executor)
      expect(job).to be_a(Karafka::Processing::Jobs::Eofed)
    end
  end

  describe '#revoked' do
    it do
      job = builder.revoked(executor)
      expect(job).to be_a(Karafka::Processing::Jobs::Revoked)
    end
  end

  describe '#shutdown' do
    it do
      job = builder.shutdown(executor)
      expect(job).to be_a(Karafka::Processing::Jobs::Shutdown)
    end
  end
end
