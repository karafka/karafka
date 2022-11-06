# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      dead_letter_queue: {
        active: true
      },
      virtual_partitions: {
        active: false
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when trying to use DLQ with VP' do
    before { config[:virtual_partitions][:active] = true }

    it { expect(check).not_to be_success }
  end
end
