# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:shutdown)
    job.call
  end

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }

  it 'expect to run shutdown on the executor' do
    expect(executor).to have_received(:shutdown).with(no_args)
  end
end
