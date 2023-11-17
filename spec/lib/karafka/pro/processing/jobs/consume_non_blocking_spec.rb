# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:time_now) { Time.now }

  it { expect(job.non_blocking?).to eq(true) }
  it { expect(described_class).to be < ::Karafka::Processing::Jobs::Consume }

  describe '#before_schedule' do
    before do
      allow(Time).to receive(:now).and_return(time_now)
      allow(executor).to receive(:before_schedule)
    end

    it 'expect to run before_schedule on the executor with time and messages' do
      job.before_schedule
      expect(executor).to have_received(:before_schedule).with(messages)
    end
  end
end
