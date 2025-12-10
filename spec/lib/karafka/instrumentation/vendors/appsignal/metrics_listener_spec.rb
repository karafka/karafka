# frozen_string_literal: true

require 'karafka/instrumentation/vendors/appsignal/metrics_listener'

RSpec.describe_current do
  subject(:listener) { described_class.new }

  describe 'events mapping' do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end

  describe 'USER_CONSUMER_ERROR_TYPES coverage' do
    it 'includes all consumer error types defined in the source code' do
      coverage = ErrorTypesChecker.check_consumer_error_types_coverage(described_class)
      missing = coverage[:missing].join(', ')

      expect(coverage[:missing]).to be_empty,
        "Appsignal metrics listener USER_CONSUMER_ERROR_TYPES is missing: #{missing}"
    end
  end
end
