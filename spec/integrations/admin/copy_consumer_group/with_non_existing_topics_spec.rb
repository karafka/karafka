# frozen_string_literal: true

# When trying to migrate with non-existing topics, it should migrate those in use (none)

setup_karafka

PREVIOUS_NAME = SecureRandom.uuid
NEW_NAME = SecureRandom.uuid

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

Karafka::Admin.seek_consumer_group(
  PREVIOUS_NAME,
  {
    DT.topics[0] => { 0 => 10 }
  }
)

# No error expected, just nothing to migrate
assert !Karafka::Admin.copy_consumer_group(
  PREVIOUS_NAME,
  NEW_NAME,
  [DT.topics[1]]
)
