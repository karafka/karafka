# frozen_string_literal: true

require 'karafka/pro/processing/jobs_builder'
require 'karafka/pro/processing/jobs/consume_non_blocking'
require 'karafka/pro/routing/extensions'

RSpec.describe_current do
  subject(:builder) { described_class.new }

  let(:executor) { build(:processing_executor) }

  before do
    executor.topic.singleton_class.include(Karafka::Pro::Routing::Extensions)
  end

  describe '#consume' do
    context 'when it is a lrj topic' do
      before { executor.topic.long_running_job = true }

      it 'expect to use the non blocking pro consumption job' do
        expect(builder.consume(executor, []))
          .to be_a(Karafka::Pro::Processing::Jobs::ConsumeNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it { expect(builder.consume(executor, [])).to be_a(Karafka::Processing::Jobs::Consume) }
    end
  end

  describe '#revoked' do
    it { expect(builder.revoked(executor)).to be_a(Karafka::Processing::Jobs::Revoked) }
  end

  describe '#shutdown' do
    it { expect(builder.shutdown(executor)).to be_a(Karafka::Processing::Jobs::Shutdown) }
  end
end
