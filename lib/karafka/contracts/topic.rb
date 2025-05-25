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

      required(:deserializers) { |val| !val.nil? }
      required(:id) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:kafka) { |val| val.is_a?(Hash) && !val.empty? }
      required(:max_messages) { |val| val.is_a?(Integer) && val >= 1 }
      required(:initial_offset) { |val| %w[earliest latest].include?(val) }
      required(:max_wait_time) { |val| val.is_a?(Integer) && val >= 10 }
      required(:name) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:active) { |val| [true, false].include?(val) }
      nested(:subscription_group_details) do
        required(:name) { |val| val.is_a?(String) && !val.empty? }
      end

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

      # When users redefine kafka scope settings per topic, they often forget to define the
      # basic stuff as they assume it is auto-inherited. It is not (unless inherit flag used),
      # leaving them with things like bootstrap.servers undefined. This checks that bootstrap
      # servers are defined so we can catch those issues before they cause more problems.
      virtual do |data, errors|
        next unless errors.empty?

        kafka = data.fetch(:kafka)

        next if kafka.key?(:'bootstrap.servers')

        [[%w[kafka bootstrap.servers], :missing]]
      end

      virtual do |data, errors|
        next unless errors.empty?
        next unless ::Karafka::App.config.strict_topics_namespacing

        value = data.fetch(:name)
        namespacing_chars_count = value.chars.find_all { |c| ['.', '_'].include?(c) }.uniq.size

        next if namespacing_chars_count <= 1

        [[%w[name], :inconsistent_namespacing]]
      end
    end
  end
end
