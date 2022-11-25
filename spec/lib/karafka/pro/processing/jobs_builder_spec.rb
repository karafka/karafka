# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { described_class.new }

  let(:executor) { build(:processing_executor) }
  let(:coordinator) { build(:processing_coordinator) }

  describe '#consume' do
    context 'when it is a lrj topic' do
      before { executor.topic.long_running_job true }

      it 'expect to use the non blocking pro consumption job' do
        job = builder.consume(executor, [], coordinator)
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::ConsumeNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it do
        job = builder.consume(executor, [], coordinator)
        expect(job).to be_a(Karafka::Processing::Jobs::Consume)
      end
    end
  end

  describe '#revoked' do
    context 'when it is a lrj topic' do
      before { executor.topic.long_running_job true }

      it 'expect to use the non blocking pro revocation job' do
        job = builder.revoked(executor)
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::RevokedNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it do
        job = builder.revoked(executor)
        expect(job).to be_a(Karafka::Processing::Jobs::Revoked)
      end
    end
  end

  describe '#shutdown' do
    it do
      job = builder.shutdown(executor)
      expect(job).to be_a(Karafka::Processing::Jobs::Shutdown)
    end
  end
end
