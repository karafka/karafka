# frozen_string_literal: true

# When the previous consumer group does not exist, it should not crash

setup_karafka

assert !Karafka::Admin.copy_consumer_group(
  'does_not_exist',
  'new_name',
  %w[non_existing_topic]
)
