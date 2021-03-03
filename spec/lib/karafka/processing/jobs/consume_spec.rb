# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:time_now) { Time.now }

  before do
    allow(Time).to receive(:now).and_return(time_now)
    allow(executor).to receive(:consume)
    job.call
  end

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }

  it 'expect to run consumption on the executor with time and messages' do
    expect(executor).to have_received(:consume).with(messages, time_now)
  end
end
