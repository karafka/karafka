# frozen_string_literal: true

# A config value set on the topic should have the `:dynamic_topic_config` source and should not
# be marked as default

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1, "retention.ms" => "123456")

resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topic)
config = Karafka::Admin::Configs.describe(resource).first.configs.find do |topic_config|
  topic_config.name == "retention.ms"
end

assert_equal "123456", config.value
assert_equal :dynamic_topic_config, config.source
assert !config.default?
assert config.synonyms.any? { |synonym| synonym.source == :dynamic_topic_config }
