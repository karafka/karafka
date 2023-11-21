# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.instance }

  after { tracker.clear }

  context 'events naming' do
    it 'expect to match correct methods' do
      expect(NotificationsChecker.valid?(tracker)).to eq(true)
    end
  end
end
