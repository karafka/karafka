# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      throttling: throttling
    }
  end

  let(:throttling) do
    {
      active: false,
      limit: 1,
      interval: 10,
      throttler_class: nil
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active is not boolean' do
    before { throttling[:active] = 1 }

    it { expect(check).not_to be_success }
  end

  context 'when limit is less than 1' do
    before { throttling[:limit] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when interval is less than 1' do
    before { throttling[:interval] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when throttler_class is not a class' do
    before { throttling[:throttler_class] = 0 }

    it { expect(check).not_to be_success }
  end
end
