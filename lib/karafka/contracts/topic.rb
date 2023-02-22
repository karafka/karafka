# frozen_string_literal: true

module Karafka
  module Contracts
    # Consumer group topic validation rules.
    class Topic < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('topic')
      end

      required(:deserializer) { |val| !val.nil? }
      required(:id) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:kafka) { |val| val.is_a?(Hash) && !val.empty? }
      required(:max_messages) { |val| val.is_a?(Integer) && val >= 1 }
      required(:initial_offset) { |val| %w[earliest latest].include?(val) }
      required(:max_wait_time) { |val| val.is_a?(Integer) && val >= 10 }
      required(:name) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:active) { |val| [true, false].include?(val) }
      required(:subscription_group) { |val| val.is_a?(String) && !val.empty? }

      # Consumer needs to be present only if topic is active
      # We allow not to define consumer for non-active because they may be only used via admin
      # api or other ways and not consumed with consumer
      virtual do |data, errors|
        next unless errors.empty?
        next if data.fetch(:consumer)
        next unless data.fetch(:active)

        [[%w[consumer], :missing]]
      end

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

      virtual do |data, errors|
        next unless errors.empty?
        next unless ::Karafka::App.config.strict_topics_namespacing

        value = data.fetch(:name)
        namespacing_chars_count = value.chars.find_all { |c| ['.', '_'].include?(c) }.uniq.count

        next if namespacing_chars_count <= 1

        [[%w[name], :inconsistent_namespacing]]
      end
    end
  end
end
