# frozen_string_literal: true

# The flat pause configuration API (config.pause_timeout, config.pause_max_timeout,
# config.pause_with_exponential_backoff) was deprecated in 2.5.2 and removed in 2.6. Only the
# nested config.pause.* namespace remains. This spec guards against the flat accessors being
# accidentally reintroduced.

setup_karafka do |config|
  config.pause.timeout = 1_500
  config.pause.max_timeout = 6_000
  config.pause.with_exponential_backoff = true
end

config = Karafka::App.config

# The nested API is the only supported way and keeps working
assert_equal 1_500, config.pause.timeout
assert_equal 6_000, config.pause.max_timeout
assert_equal true, config.pause.with_exponential_backoff

# None of the removed flat readers may respond anymore
%i[pause_timeout pause_max_timeout pause_with_exponential_backoff].each do |method_name|
  if config.respond_to?(method_name)
    raise "Expected config not to respond to removed flat reader ##{method_name}"
  end

  begin
    config.public_send(method_name)
  rescue NoMethodError
    nil
  else
    raise "Expected ##{method_name} to raise NoMethodError, but it did not"
  end
end

# None of the removed flat writers may respond anymore
{
  pause_timeout: 2_000,
  pause_max_timeout: 8_000,
  pause_with_exponential_backoff: false
}.each do |method_name, value|
  setter = :"#{method_name}="

  if config.respond_to?(setter)
    raise "Expected config not to respond to removed flat writer ##{setter}"
  end

  begin
    config.public_send(setter, value)
  rescue NoMethodError
    nil
  else
    raise "Expected ##{setter} to raise NoMethodError, but it did not"
  end
end
