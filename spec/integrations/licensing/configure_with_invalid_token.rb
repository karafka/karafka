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
