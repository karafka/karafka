# frozen_string_literal: true

# Karafka::Admin.list_consumer_groups should list KIP-848 (consumer protocol) groups and report
# them as stable while they have live members and as empty after shutdown.

setup_karafka(consumer_group_protocol: true)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  next false unless DT[0].size >= 10

  DT[:live] = Karafka::Admin.list_consumer_groups.find { |group| group[:group_id] == DT.group }

  true
end

assert_not_equal nil, DT[:live]
assert_equal :stable, DT[:live][:state]

our = Karafka::Admin.list_consumer_groups.find { |group| group[:group_id] == DT.group }

assert_not_equal nil, our
assert_equal :empty, our[:state]
