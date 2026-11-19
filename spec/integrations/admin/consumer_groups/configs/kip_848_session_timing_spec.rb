# frozen_string_literal: true

# Karafka::Admin::Configs should set the session and heartbeat timing of a KIP-848 (consumer
# protocol) consumer group with group configs, as the client-side settings are not supported for
# it, and the consumer group should keep consuming with them. Deleting them should restore the
# broker defaults.

setup_karafka(consumer_group_protocol: true)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

TIMING = {
  "consumer.session.timeout.ms" => "50000",
  "consumer.heartbeat.interval.ms" => "6000"
}.freeze

def timing_configs
  resource = Karafka::Admin::Configs::Resource.new(type: :consumer_group, name: DT.group)
  described = Karafka::Admin::Configs.describe(resource).first

  assert_equal :consumer_group, described.type
  assert_equal DT.group, described.name

  described.configs.select { |config| TIMING.key?(config.name) }
end

def wait_for_timing(expected)
  50.times do
    break if timing_configs.to_h { |config| [config.name, config.value] } == expected

    sleep(0.1)
  end
end

defaults = timing_configs

assert_equal TIMING.keys.sort, defaults.map(&:name).sort
assert defaults.all?(&:default?)

group = Karafka::Admin::Configs::Resource.new(type: :consumer_group, name: DT.group)
TIMING.each { |name, value| group.set(name, value) }
Karafka::Admin::Configs.alter(group)

wait_for_timing(TIMING)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal (0..9).to_a, DT[0]

altered = timing_configs

assert_equal TIMING, altered.to_h { |config| [config.name, config.value] }
assert altered.none?(&:default?)

group = Karafka::Admin::Configs::Resource.new(type: :consumer_group, name: DT.group)
TIMING.each_key { |name| group.delete(name) }
Karafka::Admin::Configs.alter(group)

expected_defaults = defaults.to_h { |config| [config.name, config.value] }

wait_for_timing(expected_defaults)

restored = timing_configs

assert_equal expected_defaults, restored.to_h { |config| [config.name, config.value] }
assert restored.all?(&:default?)
