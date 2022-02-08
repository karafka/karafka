# frozen_string_literal: true

# When using the pro adapter, we should be able to use partitioner that will allow us to process
# ActiveJob jobs in their scheduled order using multiple partitions

setup_karafka do |config|
  config.license.token = pro_license_token
end

setup_active_job

# integrations_2_03
