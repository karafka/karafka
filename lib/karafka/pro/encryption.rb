# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Out of the box encryption engine for both Karafka and WaterDrop
    # It uses asymmetric encryption via RSA. We use asymmetric so we can have producers that won't
    # have ability (when private key not added) to decrypt messages.
    module Encryption
      class << self
        # Sets up additional config scope, validations and other things
        #
        # @param config [Karafka::Core::Configurable::Node] root node config
        def pre_setup(config)
          # Expand the config with this feature specific stuff
          config.instance_eval do
            setting(:encryption, default: Setup::Config.config)
          end
        end

        # @param config [Karafka::Core::Configurable::Node] root node config
        def post_setup(config)
          Encryption::Contracts::Config.new.validate!(
            config.to_h,
            scope: %w[config]
          )

          # Don't inject extra components if encryption is not active
          return unless config.encryption.active

          # This parser is encryption aware
          config.internal.messages.parser = Messages::Parser.new

          # Encryption for WaterDrop
          config.producer.middleware.append(Messages::Middleware.new)
        end

        # This feature does not need any changes post-fork
        #
        # @param _config [Karafka::Core::Configurable::Node]
        # @param _pre_fork_producer [WaterDrop::Producer]
        def post_fork(_config, _pre_fork_producer)
          true
        end
      end
    end
  end
end
