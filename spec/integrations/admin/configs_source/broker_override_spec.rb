# frozen_string_literal: true

# A topic config value inherited from a broker override should have the `:dynamic_broker_config`
# source, while it is not marked as default. Its synonyms should carry their own sources, so the
# broker override and the built-in default it replaces can be told apart.

setup_karafka

BROKER_CONFIG = "log.segment.delete.delay.ms"
VALUE = "60001"

Karafka::Admin.create_topic(DT.topic, 1, 1)

broker_id = Karafka::Admin.cluster_info.brokers.first[:broker_id]
broker = Karafka::Admin::Configs::Resource.new(type: :broker, name: broker_id.to_s)
topic = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topic)

broker.set(BROKER_CONFIG, VALUE)
Karafka::Admin::Configs.alter(broker)

begin
  config = nil

  # The broker override reaches the topic config with a short delay
  20.times do
    config = Karafka::Admin::Configs.describe(topic).first.configs.find do |topic_config|
      topic_config.name == "file.delete.delay.ms"
    end

    break if config.value == VALUE

    sleep(0.5)
  end

  assert_equal VALUE, config.value
  assert_equal :dynamic_broker_config, config.source
  assert !config.default?

  synonyms = config.synonyms.map { |synonym| [synonym.name, synonym.source] }

  assert synonyms.include?([BROKER_CONFIG, :dynamic_broker_config])
  assert synonyms.include?([BROKER_CONFIG, :default_config])
ensure
  broker = Karafka::Admin::Configs::Resource.new(type: :broker, name: broker_id.to_s)
  broker.delete(BROKER_CONFIG)
  Karafka::Admin::Configs.alter(broker)
end
