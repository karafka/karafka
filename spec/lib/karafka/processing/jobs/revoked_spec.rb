# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:revoked)
    job.call
  end

  it 'expect to run revoked on the executor' do
    expect(executor).to have_received(:revoked).with(no_args).once
  end
end
