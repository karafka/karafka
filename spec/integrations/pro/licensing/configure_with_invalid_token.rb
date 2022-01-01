# frozen_string_literal: true

# Karafka should not start if the token is invalid

failed_as_expected = false

begin
  setup_karafka do |config|
    config.license.token = rand.to_s
  end
rescue Karafka::Errors::InvalidLicenseTokenError
  failed_as_expected = true
end

assert_equal true, failed_as_expected
assert_equal false, Karafka.pro?

# Pro components should not be visible
assert_equal false, const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert_equal false, const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
