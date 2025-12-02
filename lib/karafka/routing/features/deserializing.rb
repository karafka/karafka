# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Namespace for feature allowing to configure deserializers for payload, key and headers
      # Also handles parallel deserialization via Ractors when enabled
      class Deserializing < Base
        class << self
          # Initializes the Ractor pool if parallel deserializing is enabled
          # No explicit shutdown needed - Ruby terminates Ractors automatically on process exit
          #
          # @param _config [Karafka::Core::Configurable::Node] app config
          # @raise [Karafka::Errors::UnsupportedOptionError] when enabled on Ruby < 4.0
          def post_setup(_config)
            return unless Karafka::App.config.deserializing.parallel.active

            if RUBY_VERSION < '4.0' || !defined?(Ractor)
              raise(
                Karafka::Errors::UnsupportedOptionError,
                'Parallel deserializing requires Ruby 4.0+ with stable Ractor support'
              )
            end

            pool_size = Karafka::App.config.deserializing.parallel.pool_size
            Karafka::Deserializing::Parallel::Pool.instance.start(pool_size)
          end
        end
      end
    end
  end
end
