# frozen_string_literal: true

module Karafka
  module Routing
    module Features
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
          # @note Returns false if global parallel config is disabled, even if topic has it enabled
          # @note Result is cached since config values don't change after setup
          def parallel?
            return @parallel_cached unless @parallel_cached.nil?

            @parallel_cached = parallel && Karafka::App.config.deserializing.parallel.active
          end

          # @return [Object] distributor for splitting payloads across Ractor workers
          # In OSS, always returns the internal default
          # Pro can override per-topic via routing DSL
          def distributor
            Karafka::App.config.internal.deserializing.distributor
          end
        end
      end
    end
  end
end
