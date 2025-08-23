# frozen_string_literal: true

# This integration spec illustrates the all the basic ACL flows.
# Detailed ACL API specs are in the unit RSpec specs.

setup_karafka

uuid1 = "it-#{SecureRandom.uuid}"
acl1 = Karafka::Admin::Acl.new(
  resource_type: :topic,
  resource_name: uuid1,
  resource_pattern_type: :literal,
  principal: "User:#{uuid1}",
  operation: :all,
  permission_type: :allow
)

Karafka::Admin::Acl.create(acl1)
Karafka::Admin::Acl.delete(acl1)

# If this hangs it means something is not working as expected
sleep(1) until Karafka::Admin::Acl.describe(acl1).empty?
sleep(1) while Karafka::Admin::Acl.all.map(&:resource_name).include?(uuid1)

uuid2 = "it-#{SecureRandom.uuid}"
acl2 = Karafka::Admin::Acl.new(
  resource_type: :topic,
  resource_name: uuid2,
  resource_pattern_type: :literal,
  principal: "User:#{uuid2}",
  operation: :all,
  permission_type: :allow
)

Karafka::Admin::Acl.create(acl2)

sleep(1) until Karafka::Admin::Acl.describe(acl2).size == 1
sleep(1) until Karafka::Admin::Acl.all.map(&:resource_name).include?(uuid2)
