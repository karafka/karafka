# frozen_string_literal: true

# Karafka::Admin.describe_consumer_groups should describe several consumer groups in one call and
# return them in the requested order.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10
end

missing_id = "#{DT.group}-does-not-exist"

missing, existing = Karafka::Admin.describe_consumer_groups([missing_id, DT.group])

assert_equal missing_id, missing[:group_id]
assert_equal :dead, missing[:state]
assert_equal DT.group, existing[:group_id]
assert_equal :empty, existing[:state]
