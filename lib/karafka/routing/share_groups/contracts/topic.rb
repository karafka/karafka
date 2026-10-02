# frozen_string_literal: true

module Karafka
  module Routing
    module ShareGroups
      module Contracts
        # Share group topic (KIP-932 / Queues for Kafka) validation rules.
        #
        # Mirrors the consumer-group {Topic} contract for the attributes share topics share with
        # consumer topics (including `deserializers`, since share groups also process message
        # payloads, keys and headers), but omits consumer-group-only routing features that are not
        # prepended onto share topics. Reuses the `routing.topic` locale messages.
        class Topic < Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka.gem_root, "config", "locales", "errors.yml")
            ).fetch("en").fetch("validations").fetch("routing").fetch("topic")
          end

          required(:deserializers) { |val| !val.nil? }
          required(:id) { |val| val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val) }
          required(:kafka) { |val| val.is_a?(Hash) && !val.empty? }
          required(:max_messages) { |val| val.is_a?(Integer) && val >= 1 }
          required(:max_wait_time) { |val| val.is_a?(Integer) && val >= 10 }
          required(:name) { |val| val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val) }
          required(:active) { |val| [true, false].include?(val) }
          nested(:subscription_group_details) do
            required(:name) { |val| val.is_a?(String) && !val.empty? }
          end

          # Share consumers (KIP-932) do not support pattern subscriptions, so regexp-style topic
          # definitions must be rejected with a clear error instead of only the generic name-format
          # one. A `Regexp` given to `topic()` is stringified by the routing into a `"(?..."`
          # prefixed literal and a librdkafka pattern subscription string starts with `"^"` - both
          # shapes indicate the user expected regexp subscriptions to work. This virtual runs
          # independently of other errors so its message always accompanies the generic one.
          virtual do |data, _errors|
            name = data[:name].to_s

            next unless name.start_with?("^", "(?")

            [[%w[name], :regexp_subscription_not_supported]]
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

          # A share-group topic must be consumed by a share consumer. Requiring the consumer to
          # inherit from Karafka::ShareConsumer (Consumers::ShareGroup) prevents accidentally
          # wiring a consumer-group consumer onto a share group, which would run the wrong
          # (offset/pause based) flow.
          virtual do |data, errors|
            next unless errors.empty?

            consumer = data.fetch(:consumer)

            # Only actual consumer classes carry mode information, so the mode is enforced on
            # classes only. Every other value is left untouched: nil (inactive/admin-only topics
            # may have no consumer, already handled by the missing-check above) and String/Symbol
            # by-name references (a class passed for reload is resolved to a Class before it reaches
            # here, so nothing functional is skipped).
            next unless consumer.is_a?(Class)
            next if consumer <= Karafka::Consumers::ShareGroup

            [[%w[consumer], :share_consumer_required]]
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

            next if kafka.key?(:"bootstrap.servers")

            [[%w[kafka bootstrap.servers], :missing]]
          end

          virtual do |data, errors|
            next unless errors.empty?
            next unless Karafka::App.config.strict_topics_namespacing

            value = data.fetch(:name)
            namespace_chars = [".", "_"].freeze
            namespacing_chars_count = value.chars.find_all do |c|
              namespace_chars.include?(c)
            end.uniq.size

            next if namespacing_chars_count <= 1

            [[%w[name], :inconsistent_namespacing]]
          end
        end
      end
    end
  end
end
