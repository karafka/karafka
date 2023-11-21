# frozen_string_literal: true

require 'karafka/instrumentation/vendors/appsignal/metrics_listener'

RSpec.describe_current do
  subject(:listener) { described_class.new }

  describe 'events mapping' do
    it { expect(NotificationsChecker.valid?(listener)).to eq(true) }
  end
end
