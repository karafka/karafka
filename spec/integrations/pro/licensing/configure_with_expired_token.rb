# frozen_string_literal: true

# Karafka should not crash with expired token but should print an error message
# It also should work the way it works. We do not want to crash anyone processes running and
# for example restarting.
# It should aside from adding a message to logger also report an error into the monitor.

LOGS = StringIO.new

Karafka::App.monitor.subscribe('error.occurred') do |event|
  assert_equal 'licenser.expired', event[:type]
  assert_equal Karafka::Errors::ExpiredLicenseTokenError, event[:error].class
  assert_equal true, event[:error].message.include?('Your license expired on')
end

setup_karafka do |config|
  config.logger = Logger.new(LOGS)
  config.license.token = <<~TOKEN
    i6OS4XMugYjTxPUm4IIjyejEhQXnS/tzz4eSRThV1ebEYLbA6Y1x53XXsbRG
    Zx+DhTdosjH3RFmuy1J9LKVlYBa2WX9QGk6SGxVCCMiLUESnAj0VawsT20o/
    0Z22EFGkgoz9E/t1XdFAmCwYJOrns5tVtFjXIaCnSEaDnweCxLGDrk6fVYfB
    fkemJzii64BwyPlEqehIsbcH0F5rdiTonDJPtIwu36S1nuHCU/C269RQeyMc
    6UQ0n+8YfYJu8QIb5R0rnRiZQwF1jdW8IfjLRuLKi+7HQiNMjbcKoQohufsX
    xhiRyMJjMtRQpkKsFR1wrSaVXVpKMklfagXuwGioqhuy0lzWdAhNg/Vb4asG
    7FP2WbbcKJ44r36LJrHEIX4t1nuy9/Ee8RxTPxFPbEiaauDuSO4Ytzi9OkAC
    pW5tWnTrG9b1ARoS3u6hDo+OmK2t4dmk1x9RolAMUex1lwfP4Jyjj9Ff8a8U
    151nzgnqP3S4mq5zgY7lduowAUaw+wZ6
  TOKEN
end

LOGS.rewind

logs = LOGS.read

assert_equal true, logs.include?('] ERROR -- : Your license expired on 2021-01-01')
assert_equal true, logs.include?('Please reach us at contact@karafka.io')
assert_equal true, Karafka.pro?

# We do not want to break systems, so even with expired keys, pro components should be loaded
assert_equal true, const_visible?('Karafka::Pro::Processing::Jobs::ConsumeNonBlocking')
assert_equal true, const_visible?('Karafka::Pro::ActiveJob::Consumer')
assert_equal true, const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert_equal true, const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
assert_equal true, const_visible?('Karafka::Pro::PerformanceTracker')
assert_equal true, const_visible?('Karafka::Pro::Scheduler')
