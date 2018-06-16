# frozen_string_literal: true

module Karafka
  # Namespace for all the things related to Kafka connection
  module Connection
    # Mapper used to convert our internal settings into ruby-kafka settings based on their
    # API requirements.
    # Since ruby-kafka has more and more options and there are few "levels" on which
    # we have to apply them (despite the fact, that in Karafka you configure all of it
    # in one place), we have to remap it into what ruby-kafka driver requires
    # @note The good thing about Kafka.new method is that it ignores all options that
    #   do nothing. So we don't have to worry about injecting our internal settings
    #   into the client and breaking stuff
    module ApiAdapter
      class << self
        # Builds all the configuration settings for Kafka.new method
        # @return [Array<Hash>] Array with all the client arguments including hash with all
        #   the settings required by Kafka.new method
        # @note We return array, so we can inject any arguments we want, in case of changes in the
        #   raw driver
        def client
          # This one is a default that takes all the settings except special
          # cases defined in the map
          settings = {
            logger: ::Karafka.logger,
            client_id: ::Karafka::App.config.client_id
          }

          kafka_configs.each do |setting_name, setting_value|
            # All options for config adapter should be ignored as we're just interested
            # in what is left, as we want to pass all the options that are "typical"
            # and not listed in the api_adapter special cases mapping. All the values
            # from the api_adapter mapping go somewhere else, not to the client directly
            next if AttributesMap.api_adapter.values.flatten.include?(setting_name)

            settings[setting_name] = setting_value
          end

          settings_hash = sanitize(settings)

          # Normalization for the way Kafka::Client accepts arguments from  0.5.3
          [settings_hash.delete(:seed_brokers), settings_hash]
        end

        # Builds all the configuration settings for kafka#consumer method
        # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Array<Hash>] array with all the consumer arguments including hash with all
        #   the settings required by Kafka#consumer
        def consumer(consumer_group)
          settings = { group_id: consumer_group.id }
          settings = fetch_for(:consumer, consumer_group, settings)
          [sanitize(settings)]
        end

        # Builds all the configuration settings for kafka consumer consume_each_batch and
        #   consume_each_message methods
        # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Array<Hash>] Array with all the arguments required by consuming method
        #   including hash with all the settings required by
        #   Kafka::Consumer#consume_each_message and Kafka::Consumer#consume_each_batch method
        def consumption(consumer_group)
          [
            sanitize(
              fetch_for(
                :consumption,
                consumer_group,
                automatically_mark_as_processed: consumer_group.automatically_mark_as_consumed
              )
            )
          ]
        end

        # Builds all the configuration settings for kafka consumer#subscribe method
        # @param topic [Karafka::Routing::Topic] topic that holds details for a given subscription
        # @return [Hash] hash with all the settings required by kafka consumer#subscribe method
        def subscribe(topic)
          settings = fetch_for(:subscribe, topic)
          [Karafka::App.config.topic_mapper.outgoing(topic.name), sanitize(settings)]
        end

        # Builds all the configuration settings required by kafka consumer#pause method
        # @param topic [String] topic that we want to pause
        # @param partition [Integer] number partition that we want to pause
        # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group details
        # @return [Array] array with all the details required to pause kafka consumer
        def pause(topic, partition, consumer_group)
          [
            Karafka::App.config.topic_mapper.outgoing(topic),
            partition,
            { timeout: consumer_group.pause_timeout }
          ]
        end

        # Remaps topic details taking the topic mapper feature into consideration.
        # @param params [Karafka::Params::Params] params instance
        # @return [Array] array with all the details needed by ruby-kafka to mark message
        #   as processed
        # @note When default empty topic mapper is used, no need for any conversion as the
        #   internal and external format are exactly the same
        def mark_message_as_processed(params)
          # Majority of non heroku users don't use custom topic mappers. No need to change
          # anything when it is a default mapper that does not change anything
          return [params] if Karafka::App.config.topic_mapper == Karafka::Routing::TopicMapper

          # @note We don't use tap as it is around 13% slower than non-dup version
          dupped = params.dup
          dupped['topic'] = Karafka::App.config.topic_mapper.outgoing(params.topic)
          [dupped]
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
            next unless AttributesMap.api_adapter[namespace_key].include?(setting_name)
            # Ignore settings that are already initialized
            # In case they are in preexisting settings fetched differently
            next if preexisting_settings.key?(setting_name)
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
