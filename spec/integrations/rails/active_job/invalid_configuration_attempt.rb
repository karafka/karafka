# frozen_string_literal: true

# When there is a misconfiguration of karafka options on ActiveJob job class, it should raise an
# error

setup_active_job

def handle
  yield
  DT[0] << false
rescue Karafka::Errors::InvalidConfigurationError
  DT[0] << true
end

Job = Class.new(ActiveJob::Base)

handle { Job.karafka_options(dispatch_method: :na) }
handle { Job.karafka_options(dispatch_method: :produce_async) }
handle { Job.karafka_options(dispatch_method: rand) }

assert DT[0][0]
assert_equal false, DT[0][1]
assert DT[0][2]
