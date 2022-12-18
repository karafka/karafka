# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
          Encryption::Contracts::Config.new.validate!(config.to_h)

          # Don't inject extra components if encryption is not active
          return unless config.encryption.active

          # This parser is encryption aware
          config.internal.messages.parser = Messages::Parser.new

          # Encryption for WaterDrop
          config.producer.middleware.append(Messages::Middleware.new)
        end
      end
    end
  end
end
