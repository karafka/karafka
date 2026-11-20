# frozen_string_literal: true

module Karafka
  module Swarm
    # Builds a new WaterDrop producer that inherits configuration from an old one
    #
    # When a swarm node forks, the parent's producer must be replaced with a new one.
    # This class encapsulates the logic for building that new producer, inheriting all relevant
    # settings from the old one while generating fresh connection-level configuration.
    class ProducerReplacer
      include Helpers::ConfigImporter.new(
        nodes: %i[swarm nodes]
      )

      # Attributes that should not be directly copied from the old producer config because they
      # are either regenerated fresh (kafka, logger, id) or handled via their own namespaced
      # migration (oauth, polling, polling.fd).
      SKIPPABLE_ATTRIBUTES = %i[
        id
        kafka
        logger
        oauth
        polling
        fd
      ].freeze

      private_constant :SKIPPABLE_ATTRIBUTES

      # Builds a new WaterDrop producer inheriting configuration from the old one
      #
      # @param old_producer [WaterDrop::Producer] the old producer to inherit settings from
      # @param kafka [Hash] app-level kafka configuration
      # @param logger [Object] logger instance for the new producer
      # @param node_id [Integer] id of the swarm node the producer is built for
      # @return [WaterDrop::Producer] new producer with inherited configuration
      def call(old_producer, kafka, logger, node_id)
        old_producer_config = old_producer.config

        WaterDrop::Producer.new do |p_config|
          p_config.logger = logger

          migrate_kafka(p_config, old_producer_config, kafka)
          inject_transactional_id(p_config, node_id)
          migrate_root(p_config, old_producer_config)
          migrate_oauth(p_config, old_producer_config)
          migrate_polling(p_config, old_producer_config)
          migrate_polling_fd(p_config, old_producer_config)
        end
      end

      private

      # Migrates root-level producer attributes from the old producer, skipping those that are
      # regenerated fresh or handled by their own namespaced migration
      #
      # @param p_config [WaterDrop::Config] new producer config being built
      # @param old_producer_config [WaterDrop::Config] old producer config to inherit from
      def migrate_root(p_config, old_producer_config)
        old_producer_config.to_h.each do |key, value|
          next if SKIPPABLE_ATTRIBUTES.include?(key)

          p_config.public_send("#{key}=", value)
        end
      end

      # Builds fresh kafka config from app-level settings and preserves any producer-specific
      # kafka settings from the old producer (e.g., enable.idempotence) that aren't in the
      # base app kafka config
      #
      # @param p_config [WaterDrop::Config] new producer config being built
      # @param old_producer_config [WaterDrop::Config] old producer config to inherit from
      # @param kafka [Hash] app-level kafka configuration
      def migrate_kafka(p_config, old_producer_config, kafka)
        p_config.kafka = Setup::AttributesMap.producer(kafka.dup)

        old_producer_config.kafka.each do |key, value|
          next if p_config.kafka.key?(key)

          p_config.kafka[key] = value
        end
      end

      # Makes the `transactional.id` unique per node, so nodes do not fence each other, and stable
      # across node restarts, so Kafka can finish the transactions of the previous node instance.
      # A single node keeps the configured id unchanged.
      #
      # @param p_config [WaterDrop::Config] new producer config being built
      # @param node_id [Integer] id of the swarm node the producer is built for
      def inject_transactional_id(p_config, node_id)
        transactional_id = p_config.kafka[:"transactional.id"]

        return unless transactional_id
        return if nodes == 1

        p_config.kafka[:"transactional.id"] = "#{transactional_id}_#{node_id}"
      end

      # Migrates oauth configuration from the old producer
      #
      # @param p_config [WaterDrop::Config] new producer config being built
      # @param old_producer_config [WaterDrop::Config] old producer config to inherit from
      def migrate_oauth(p_config, old_producer_config)
        old_producer_config.oauth.to_h.each do |key, value|
          p_config.oauth.public_send("#{key}=", value)
        end
      end

      # Migrates polling configuration from the old producer
      #
      # @param p_config [WaterDrop::Config] new producer config being built
      # @param old_producer_config [WaterDrop::Config] old producer config to inherit from
      def migrate_polling(p_config, old_producer_config)
        old_producer_config.polling.to_h.each do |key, value|
          next if SKIPPABLE_ATTRIBUTES.include?(key)

          p_config.polling.public_send("#{key}=", value)
        end
      end

      # Migrates polling fd configuration from the old producer
      #
      # @param p_config [WaterDrop::Config] new producer config being built
      # @param old_producer_config [WaterDrop::Config] old producer config to inherit from
      def migrate_polling_fd(p_config, old_producer_config)
        old_producer_config.polling.fd.to_h.each do |key, value|
          p_config.polling.fd.public_send("#{key}=", value)
        end
      end
    end
  end
end
