# frozen_string_literal: true

# Reading and changing consumer group offsets should go through the admin API only, without
# creating any consumer bound to the consumer group

setup_karafka

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

produce_many(DT.topic, DT.uuids(10), partition: 0)
produce_many(DT.topic, DT.uuids(10), partition: 1)

module ConsumersTracker
  def consumer(...)
    DT[:consumers] << true

    super
  end
end

Rdkafka::Config.prepend(ConsumersTracker)

Karafka::Admin.seek_consumer_group(
  DT.group,
  { DT.topic => { 0 => 3, 1 => (Time.now + 60) } }
)

Karafka::Admin.copy_consumer_group(DT.group, DT.groups[1], [DT.topic])

lags = Karafka::Admin.read_lags_with_offsets(
  { DT.group => [DT.topic], DT.groups[1] => [DT.topic] }
)

[DT.group, DT.groups[1]].each do |group|
  assert_equal(
    { 0 => { offset: 3, lag: 7 }, 1 => { offset: 10, lag: 0 } },
    lags.fetch(group).fetch(DT.topic)
  )
end

assert DT[:consumers].empty?
