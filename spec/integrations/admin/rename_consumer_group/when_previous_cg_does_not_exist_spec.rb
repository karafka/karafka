# frozen_string_literal: true

# When the previous consumer group does not exist, it should return false

setup_karafka

assert !Karafka::Admin.rename_consumer_group(
  'does_not_exist',
  'new_name',
  %w[non_existing_topic]
)
