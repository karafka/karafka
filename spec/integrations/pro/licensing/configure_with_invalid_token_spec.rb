# frozen_string_literal: true

# Karafka should not start if the token is invalid

failed_as_expected = false

ENV['KARAFKA_PRO_LICENSE_TOKEN'] = rand.to_s

begin
  setup_karafka
rescue Karafka::Errors::InvalidLicenseTokenError
  failed_as_expected = true
end

assert failed_as_expected
assert_equal false, Karafka.pro?

# No need to check visibility of anything because we raise exception
