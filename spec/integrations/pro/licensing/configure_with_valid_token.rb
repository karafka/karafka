# frozen_string_literal: true

# Pro components should be loaded when we run in pro mode and a nice message should be printed

LOGS = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(LOGS)
  config.license.token = pro_license_token
end

LOGS.rewind

logs = LOGS.read

assert_equal false, logs.include?('] ERROR -- : Your license expired')
assert_equal false, logs.include?('Please reach us')
assert_equal true, Karafka.pro?
assert_equal true, const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert_equal true, const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
