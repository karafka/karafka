# frozen_string_literal: true

module Karafka
  module Contracts
    # Consumer group topic validation rules.
    class ConsumerGroupTopic < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('consumer_group_topic')
      end

      required(:consumer) { |consumer_group| !consumer_group.nil? }
      required(:deserializer) { |deserializer| !deserializer.nil? }
      required(:id) { |id| id.is_a?(String) && Contracts::TOPIC_REGEXP.match?(id) }
      required(:kafka) { |kafka| kafka.is_a?(Hash) && !kafka.empty? }
      required(:max_messages) { |mm| mm.is_a?(Integer) && mm >= 1 }
      required(:initial_offset) { |io| %w[earliest latest].include?(io) }
      required(:max_wait_time) { |mwt| mwt.is_a?(Integer) && mwt >= 10 }
      required(:manual_offset_management) { |mmm| [true, false].include?(mmm) }
      required(:name) { |name| name.is_a?(String) && Contracts::TOPIC_REGEXP.match?(name) }

      virtual do |data, errors|
        next unless errors.empty?

        value = data.fetch(:kafka)

        begin
          # This will trigger rdkafka validations that we catch and re-map the info and use dry
          # compatible format
          Rdkafka::Config.new(value).send(:native_config)

          nil
        rescue Rdkafka::Config::ConfigError => e
          [[%w[kafka], e.message]]
        end
      end
    end
  end
end
