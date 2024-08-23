# frozen_string_literal: true

# When the previous consumer group does not exist, it should crash

setup_karafka

failed = false

begin
  Karafka::Admin.rename_consumer_group(
    'does_not_exist',
    'new_name',
    %w[non_existing_topic]
  )
rescue Rdkafka::RdkafkaError
  failed = true
end

assert failed
