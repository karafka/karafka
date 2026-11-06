# frozen_string_literal: true

# Seeking a consumer group that has active members should raise a clear error and leave its
# committed offsets unchanged, as Kafka accepts offset changes only for empty consumer groups

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    mark_as_consumed!(messages.last)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  next false unless DT[:offsets].size >= 10

  begin
    Karafka::Admin.seek_consumer_group(DT.group, { DT.topic => { 0 => 0 } })
  rescue Karafka::Errors::ConsumerGroupNotEmptyError => e
    DT[:error] = e
  end

  true
end

assert DT[:error].is_a?(Karafka::Errors::ConsumerGroupNotEmptyError)
assert DT[:error].message.include?(DT.group)

offsets = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal 10, offsets.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)

# Once the consumer group is stopped, its offsets can be changed
Karafka::Admin.seek_consumer_group(DT.group, { DT.topic => { 0 => 0 } })

offsets = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal 0, offsets.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)
