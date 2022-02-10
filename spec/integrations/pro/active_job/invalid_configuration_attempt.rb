# frozen_string_literal: true

# When there is a misconfiguration of karafka options on ActiveJob job class, it should raise an
# error

setup_karafka do |config|
  config.license.token = pro_license_token
end

setup_active_job

def handle
  yield
  DataCollector.data[0] << false
rescue Karafka::Errors::InvalidConfigurationError
  DataCollector.data[0] << true
end

Job = Class.new(ActiveJob::Base)

class Partitioner
  def call(_job)
    rand
  end
end

NotPartitioner = Class.new

handle { Job.karafka_options(dispatch_method: :na) }
handle { Job.karafka_options(dispatch_method: :produce_async) }
handle { Job.karafka_options(dispatch_method: rand) }
handle { Job.karafka_options(partitioner: rand) }
handle { Job.karafka_options(partitioner: ->(job) { job.job_id }) }
handle { Job.karafka_options(partitioner: Partitioner.new) }
handle { Job.karafka_options(partitioner: NotPartitioner.new) }

assert_equal true, DataCollector.data[0][0]
assert_equal false, DataCollector.data[0][1]
assert_equal true, DataCollector.data[0][2]
assert_equal true, DataCollector.data[0][3]
assert_equal false, DataCollector.data[0][4]
assert_equal false, DataCollector.data[0][5]
assert_equal true, DataCollector.data[0][6]
