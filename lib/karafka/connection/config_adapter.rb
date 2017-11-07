# frozen_string_literal: true

module Karafka
  # Namespace for all the things related to Kafka connection
  module Connection
    # Mapper used to convert our internal settings into ruby-kafka settings
    # Since ruby-kafka has more and more options and there are few "levels" on which
    # we have to apply them (despite the fact, that in Karafka you configure all of it
    # in one place), we have to remap it into what ruby-kafka driver requires
    # @note The good thing about Kafka.new method is that it ignores all options that
    #   do nothing. So we don't have to worry about injecting our internal settings
    #   into the client and breaking stuff
    module ConfigAdapter
      class << self
        # Builds all the configuration settings for Kafka.new method
        # @param _consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Hash] hash with all the settings required by Kafka.new method
        def client(_consumer_group)
          # This one is a default that takes all the settings except special
          # cases defined in the map
          settings = {
            logger: ::Karafka.logger,
            client_id: ::Karafka::App.config.client_id
          }

          kafka_configs.each do |setting_name, setting_value|
            # All options for config adapter should be ignored as we're just interested
            # in what is left, as we want to pass all the options that are "typical"
            # and not listed in the config_adapter special cases mapping. All the values
            # from the config_adapter mapping go somewhere else, not to the client directly
            next if AttributesMap.config_adapter.values.flatten.include?(setting_name)

            settings[setting_name] = setting_value
          end

          sanitize(settings)
        end

        # Builds all the configuration settings for kafka#consumer method
        # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Hash] hash with all the settings required by Kafka#consumer method
        def consumer(consumer_group)
          settings = { group_id: consumer_group.id }
          settings = fetch_for(:consumer, consumer_group, settings)
          sanitize(settings)
        end

        # Builds all the configuration settings for kafka consumer consume_each_batch and
        #   consume_each_message methods
        # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Hash] hash with all the settings required by
        #   Kafka::Consumer#consume_each_message and Kafka::Consumer#consume_each_batch method
        def consuming(consumer_group)
          settings = {
            automatically_mark_as_processed: consumer_group.automatically_mark_as_consumed
          }
          sanitize(fetch_for(:consuming, consumer_group, settings))
        end

        # Builds all the configuration settings for kafka consumer#subscribe method
        # @param topic [Karafka::Routing::Topic] topic that holds details for a given subscription
        # @return [Hash] hash with all the settings required by kafka consumer#subscribe method
        def subscription(topic)
          settings = fetch_for(:subscription, topic)
          [Karafka::App.config.topic_mapper.outgoing(topic.name), sanitize(settings)]
        end

        # Builds all the configuration settings required by kafka consumer#pause method
        # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Hash] hash with all the settings required to pause kafka consumer
        def pausing(consumer_group)
          { timeout: consumer_group.pause_timeout }
        end

        private

        # Fetches proper settings for a given map namespace
        # @param namespace_key [Symbol] namespace from attributes map config adapter hash
        # @param route_layer [Object] route topic or consumer group
        # @param preexisting_settings [Hash] hash with some preexisting settings that might have
        #   been loaded in a different way
        def fetch_for(namespace_key, route_layer, preexisting_settings = {})
          kafka_configs.each_key do |setting_name|
            # Ignore settings that are not related to our namespace
            next unless AttributesMap.config_adapter[namespace_key].include?(setting_name)
            # Ignore settings that are already initialized
            # In case they are in preexisting settings fetched differently
            next if preexisting_settings.keys.include?(setting_name)
            # Fetch all the settings from a given layer object. Objects can handle the fallback
            # to the kafka settings, so
            preexisting_settings[setting_name] = route_layer.send(setting_name)
          end

          preexisting_settings
        end

        # Removes nil containing keys from the final settings so it can use Kafkas driver
        #   defaults for those
        # @param settings [Hash] settings that may contain nil values
        # @return [Hash] settings without nil using keys (non of karafka options should be nil)
        def sanitize(settings)
          settings.reject { |_key, value| value.nil? }
        end

        # @return [Hash] Kafka config details as a hash
        def kafka_configs
          ::Karafka::App.config.kafka.to_h
        end
      end
    end
  end
end
