# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli
    # Info Karafka Cli action
    class Info < Base
      include Helpers::ConfigImporter.new(
        concurrency: %i[concurrency],
        license: %i[license],
        client_id: %i[client_id]
      )

      desc "Prints configuration details and other options of your application"

      option(
        :extended,
        "Print extended info including routing, config, and kafka details",
        TrueClass,
        %w[--extended]
      )

      # Nice karafka banner
      BANNER = <<~BANNER

        @@@                                             @@@@@  @@@
        @@@                                            @@@     @@@
        @@@  @@@    @@@@@@@@@   @@@ @@@   @@@@@@@@@  @@@@@@@@  @@@  @@@@   @@@@@@@@@
        @@@@@@     @@@    @@@   @@@@@    @@@    @@@    @@@     @@@@@@@    @@@    @@@
        @@@@@@@    @@@    @@@   @@@     @@@@    @@@    @@@     @@@@@@@    @@@    @@@
        @@@  @@@@  @@@@@@@@@@   @@@      @@@@@@@@@@    @@@     @@@  @@@@   @@@@@@@@@@

      BANNER

      # Core topic attributes to exclude when detecting features from topic#to_h
      CORE_TOPIC_ATTRIBUTES = %i[
        id
        name
        active
        consumer
        consumer_group_id
        subscription_group_details
        kafka
        max_messages
        max_wait_time
        initial_offset
        consumer_persistence
        pause_timeout
        pause_max_timeout
        pause_with_exponential_backoff
      ].freeze

      # Core consumer group attributes to exclude when detecting features from
      # consumer_group#to_h
      CORE_CONSUMER_GROUP_ATTRIBUTES = %i[
        id
        topics
      ].freeze

      private_constant :CORE_TOPIC_ATTRIBUTES, :CORE_CONSUMER_GROUP_ATTRIBUTES

      # Print configuration details and other options of your application
      def call
        Karafka.logger.info(BANNER)
        Karafka.logger.info((core_info + license_info).join("\n"))

        return unless options.fetch(:extended, false)

        Karafka.logger.info("\n")
        Karafka.logger.info(routing_info.join("\n"))
        Karafka.logger.info("\n")
        Karafka.logger.info(config_info.join("\n"))
        Karafka.logger.info("\n")
        Karafka.logger.info(kafka_config_info.join("\n"))
      end

      private

      # @return [Array<String>] core framework related info
      def core_info
        postfix = Karafka.pro? ? " + Pro" : ""

        [
          "Karafka version: #{Karafka::VERSION}#{postfix}",
          "Ruby version: #{RUBY_DESCRIPTION}",
          "Rdkafka version: #{::Rdkafka::VERSION}",
          "Consumer groups count: #{Karafka::App.routes.size}",
          "Subscription groups count: #{Karafka::App.subscription_groups.values.flatten.size}",
          "Workers count: #{concurrency}",
          "Instance client id: #{client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}"
        ]
      end

      # @return [Array<String>] license related info
      def license_info
        if Karafka.pro?
          [
            "License: Commercial",
            "License entity: #{license.entity}"
          ]
        else
          [
            "License: LGPL-3.0"
          ]
        end
      end

      # @return [Array<String>] routing details for all consumer groups
      def routing_info
        lines = [green("========== Routing ==========")]

        Karafka::App.consumer_groups.each do |consumer_group|
          active_label = consumer_group.active? ? "active" : "inactive"
          lines << ""
          lines << "Consumer group: #{consumer_group.name} (#{active_label})"

          consumer_group_features_info(consumer_group, lines)

          consumer_group.subscription_groups.each do |subscription_group|
            subscription_group_info(subscription_group, lines)
          end
        end

        lines
      end

      # Appends consumer group level feature info
      # @param consumer_group [Karafka::Routing::ConsumerGroup]
      # @param lines [Array<String>] output accumulator
      def consumer_group_features_info(consumer_group, lines)
        cg_hash = consumer_group.to_h
        features = extract_features(cg_hash, CORE_CONSUMER_GROUP_ATTRIBUTES)

        return if features.empty?

        lines << "  Features:"

        features.each do |feature_name, feature_config|
          lines << "    #{feature_name}: #{format_feature_config(feature_config)}"
        end
      end

      # Appends subscription group details to lines
      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      # @param lines [Array<String>] output accumulator
      def subscription_group_info(subscription_group, lines)
        sg_active = subscription_group.active? ? "active" : "inactive"
        lines << ""
        lines << "  Subscription group: #{subscription_group.name} " \
                 "[position: #{subscription_group.position}] (#{sg_active})"
        lines << "    kafka[group.id]: #{subscription_group.kafka[:"group.id"]}"
        lines << "    max_messages: #{subscription_group.max_messages}"
        lines << "    max_wait_time: #{subscription_group.max_wait_time}"

        if subscription_group.respond_to?(:multiplexing?) && subscription_group.multiplexing?
          mx = subscription_group.multiplexing
          lines << "    multiplexing: min=#{mx.min}, max=#{mx.max}, boot=#{mx.boot}"
        end

        subscription_group.topics.each do |topic|
          topic_info(topic, lines)
        end
      end

      # Appends topic details to lines
      # @param topic [Karafka::Routing::Topic]
      # @param lines [Array<String>] output accumulator
      def topic_info(topic, lines)
        topic_active = topic.active? ? "active" : "inactive"
        lines << ""
        lines << "    Topic: #{topic.name} (#{topic_active})"
        lines << "      consumer: #{topic.consumer}"
        lines << "      max_messages: #{topic.max_messages}"
        lines << "      max_wait_time: #{topic.max_wait_time}"
        lines << "      initial_offset: #{topic.initial_offset}"
        lines << "      consumer_persistence: #{topic.consumer_persistence}"
        lines << "      pause_timeout: #{topic.pause_timeout}"
        lines << "      pause_max_timeout: #{topic.pause_max_timeout}"
        lines << "      pause_with_exponential_backoff: #{topic.pause_with_exponential_backoff}"

        topic_kafka = topic.kafka

        unless topic_kafka.empty? || topic_kafka.equal?(Karafka::App.config.kafka)
          lines << "      kafka overrides: #{topic_kafka.inspect}"
        end

        topic_features_info(topic, lines)
      end

      # Appends topic feature details to lines
      # @param topic [Karafka::Routing::Topic]
      # @param lines [Array<String>] output accumulator
      def topic_features_info(topic, lines)
        topic_hash = topic.to_h
        features = extract_features(topic_hash, CORE_TOPIC_ATTRIBUTES)

        return if features.empty?

        lines << "      Features:"

        features.each do |feature_name, feature_config|
          lines << "        #{feature_name}: #{format_feature_config(feature_config)}"
        end
      end

      # Extracts active features from a hash by filtering out core attributes
      # @param hash [Hash] the full hash from #to_h
      # @param core_keys [Array<Symbol>] keys to exclude
      # @return [Hash] feature_name => feature_config for active features
      def extract_features(hash, core_keys)
        features = {}

        hash.each do |key, value|
          next if core_keys.include?(key)
          next unless value.is_a?(Hash)
          next unless value[:active]

          features[key] = value
        end

        features
      end

      # Formats a feature config hash for display
      # @param config [Hash] feature configuration
      # @return [String] formatted string
      def format_feature_config(config)
        config
          .except(:active)
          .map { |k, v| "#{k}=#{v.inspect}" }
          .join(", ")
      end

      # @return [Array<String>] application config details
      def config_info
        config = Karafka::App.config

        lines = [green("========== Config ==========")]
        lines << "client_id: #{config.client_id}"
        lines << "group_id: #{config.group_id}"
        lines << "concurrency: #{config.concurrency}"
        lines << "max_messages: #{config.max_messages}"
        lines << "max_wait_time: #{config.max_wait_time}"
        lines << "initial_offset: #{config.initial_offset}"
        lines << "shutdown_timeout: #{config.shutdown_timeout}"
        lines << "consumer_persistence: #{config.consumer_persistence}"
        lines << "pause_timeout: #{config.pause.timeout}"
        lines << "pause_max_timeout: #{config.pause.max_timeout}"
        lines << "pause_with_exponential_backoff: #{config.pause.with_exponential_backoff}"
        lines << "strict_topics_namespacing: #{config.strict_topics_namespacing}"
        lines << "strict_declarative_topics: #{config.strict_declarative_topics}"
        lines
      end

      # @return [Array<String>] kafka configuration details
      def kafka_config_info
        lines = [green("========== Kafka Config ==========")]

        Karafka::App.config.kafka.each do |key, value|
          lines << "#{key}: #{value}"
        end

        lines
      end
    end
  end
end
