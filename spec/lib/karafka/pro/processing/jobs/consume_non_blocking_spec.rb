# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages, coordinator) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:coordinator) { build(:processing_coordinator) }
  let(:time_now) { Time.now }

  it { expect(job.non_blocking?).to eq(true) }
  it { expect(described_class).to be < ::Karafka::Processing::Jobs::Consume }

  describe '#before_enqueue' do
    before do
      allow(Time).to receive(:now).and_return(time_now)
      allow(executor).to receive(:before_enqueue)
    end

    it 'expect to run before_enqueue on the executor with time and messages' do
      job.before_enqueue
      expect(executor).to have_received(:before_enqueue).with(messages, coordinator)
    end
  end
end
