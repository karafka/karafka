# frozen_string_literal: true

# A config value no one has set should have the `:default_config` source and should be marked as
# default

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topic)
config = Karafka::Admin::Configs.describe(resource).first.configs.find do |topic_config|
  topic_config.name == "compression.type"
end

assert_equal :default_config, config.source
assert config.default?
