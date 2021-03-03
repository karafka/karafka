# frozen_string_literal: true

module Karafka
  module Contracts
    # Consumer group topic validation rules.
    class ConsumerGroupTopic < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      params do
        required(:consumer).filled
        required(:deserializer).filled
        required(:id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:kafka).filled
        required(:max_messages) { int? & gteq?(1) }
        required(:max_wait_time).filled { int? & gteq?(10) }
        required(:manual_offset_management).filled(:bool?)
        required(:name).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
      end

      rule(:kafka) do
        # This will trigger rdkafka validations that we catch and re-map the info and use dry
        # compatible format
        Rdkafka::Config.new(value).send(:native_config)
      rescue Rdkafka::Config::ConfigError => e
        key(:kafka).failure(e.message)
      end
    end
  end
end
