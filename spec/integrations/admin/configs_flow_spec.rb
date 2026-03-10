# frozen_string_literal: true

# This integration spec illustrates the all the basic Admin configs flows.
# Detailed Configs API specs are in the unit RSpec specs.

setup_karafka

# We do not use this but this will create needed topics
draw_routes do
  topic DT.topics[0] do
    active(false)
  end

  topic DT.topics[1] do
    active(false)
  end
end

# Lets read broker settings
broker = Karafka::Admin::Configs::Resource.new(type: :broker, name: "1")

Karafka::Admin::Configs.describe(broker).each do |fetched_broker|
  fetched_broker.type
  fetched_broker.name

  fetched_broker.configs.each do |config|
    config.name
    config.value
    config.read_only?
    config.default?
    config.synonym?
  end
end

# Now lets change some settings of few topics
topic1 = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[0])
topic2 = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[1])

topic1.set("delete.retention.ms", 86_800_123)
topic1.set("cleanup.policy", "compact")
topic2.delete("delete.retention.ms")

Karafka::Admin::Configs.alter(topic1, topic2)

# Wait because it can take a bit of time for topic to update config setup in kafka
sleep(5)

# And lets now verify that those settings were indeed changed

rtopic1, rtopic2 = Karafka::Admin::Configs.describe(topic1, topic2)

assert_equal rtopic1.name, DT.topics[0]
assert_equal :topic, rtopic1.type
assert_equal rtopic2.name, DT.topics[1]
assert_equal :topic, rtopic2.type

rtopic1.configs.each do |config|
  if config.name == "delete.retention.ms"
    assert_equal "delete.retention.ms", config.name
    assert_equal "86800123", config.value
  end

  if config.name == "cleanup.policy"
    assert_equal "cleanup.policy", config.name
    assert_equal "compact", config.value
  end
end

rtopic2.configs.each do |config|
  if config.name == "delete.retention.ms"
    assert_equal "delete.retention.ms", config.name
    assert_equal "86400000", config.value
  end
end
