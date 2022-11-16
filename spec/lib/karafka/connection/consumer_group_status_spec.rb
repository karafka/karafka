# frozen_string_literal: true

RSpec.describe_current do
  subject(:status) { described_class.new(2) }

  context 'when all work is done' do
    before { 2.times { status.finish } }

    it { expect(status.working?).to eq(false) }
  end

  context 'when we tried to finish too much work' do
    before { 2.times { status.finish } }

    let(:expected_error) { Karafka::Errors::InvalidConsumerGroupStatusError }

    it { expect { status.finish }.to raise_error(expected_error) }
  end

  context 'when we finished some of the work' do
    before { status.finish }

    it { expect(status.working?).to eq(true) }
  end
end
