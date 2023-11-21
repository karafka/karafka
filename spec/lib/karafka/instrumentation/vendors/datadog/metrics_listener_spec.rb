# frozen_string_literal: true

require 'karafka/instrumentation/vendors/datadog/metrics_listener'

# This is fully covered in the integration suite
RSpec.describe_current do
  subject(:listener) { described_class.new }

  describe 'events mapping' do
    it { expect(NotificationsChecker.valid?(listener)).to eq(true) }
  end
end
