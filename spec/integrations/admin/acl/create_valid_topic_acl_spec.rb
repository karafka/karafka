# frozen_string_literal: true

# We should be able to remove consumer group and start from beginning using the Admin API

setup_karafka

acl = Karafka::Admin::Acl.new(
  resource_type: :topic,
  resource_name: 'default',
  resource_pattern_type: :literal,
  principal: 'User:x',
  operation: :all,
  permission_type: :allow
)

p acl.to_native

#p acl.class.create(acl)
#p acl.class.delete(acl)
#p acl.class.describe(acl)
