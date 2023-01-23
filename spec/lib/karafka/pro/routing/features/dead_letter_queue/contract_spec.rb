# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      dead_letter_queue: {
        active: true,
        max_retries: 1
      },
      virtual_partitions: {
        active: false
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when trying to use DLQ with VP without any retries' do
    before do
      config[:virtual_partitions][:active] = true
      config[:dead_letter_queue][:max_retries] = 0
    end

    it { expect(check).not_to be_success }
  end
end
