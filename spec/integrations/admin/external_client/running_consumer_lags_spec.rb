# frozen_string_literal: true

# A running consumer should be able to read its own group lags and offsets through its own
# connection client provided as the external client, without dedicated per-call consumer
# instances and without disturbing the ongoing consumption in any way.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    mark_as_consumed!(messages.last)

    DT[:lags] << Karafka::Admin::ConsumerGroups
      .new(external_client: client)
      .read_lags_with_offsets({ topic.consumer_group.id => [topic.name] })
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

second_wave = false

start_karafka_and_wait_until do
  # Once the first batch got consumed and lags were read via the external client, produce more
  # to prove consumption continues undisturbed after the in-consumer admin usage
  if DT[:offsets].size >= 10 && !second_wave
    second_wave = true
    produce_many(DT.topic, DT.uuids(5))
  end

  DT[:offsets].size >= 15
end

CG = Karafka::App.routes.first.id

assert !DT[:lags].empty?

# Every read must be keyed with the queried group and topic and report sane values
DT[:lags].each do |lags|
  partition_data = lags.fetch(CG).fetch(DT.topic).fetch(0)

  assert partition_data.fetch(:offset) >= -1
  assert partition_data.fetch(:lag) >= 0
end

# The last read happened after marking the last consumed message, so it must reflect the fully
# caught up group state
last_partition_data = DT[:lags].last.fetch(CG).fetch(DT.topic).fetch(0)

assert_equal 15, last_partition_data.fetch(:offset)
assert_equal 0, last_partition_data.fetch(:lag)
