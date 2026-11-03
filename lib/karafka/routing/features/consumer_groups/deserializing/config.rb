# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ConsumerGroups
        class Deserializing < Base
          # Config of this feature
          Config = Struct.new(
            :active,
            :payload,
            :key,
            :headers,
            :parallel,
            keyword_init: true
          ) do
            alias_method :active?, :active

            # @return [Boolean] is parallel deserialization enabled for this topic
            # @note Returns false if global parallel config is disabled, even if the topic
            #   has it enabled
            # @note Result is cached since config values don't change after setup
            # @note Returns false with a custom messages parser (for example Pro encryption), as
            #   Ractor workers call the deserializer directly and would bypass it
            def parallel?
              return @parallel_cached unless @parallel_cached.nil?

              config = Karafka::App.config

              @parallel_cached = (
                parallel &&
                config.deserializing.parallel.active &&
                config.internal.messages.parser.instance_of?(Karafka::Messages::Parser)
              ) || false
            end

            # @return [Object] distributor for splitting payloads across Ractor workers
            def distributor
              Karafka::App.config.internal.deserializing.distributor
            end
          end
        end
      end
    end
  end
end
