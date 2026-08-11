# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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

          # Registered as a config-phase constraint (verified centrally during setup together
          # with all other environment requirements) instead of being checked ad hoc here
          Karafka::Constraints.register(:pro_encryption_envelope_openssl, phase: :config) do |cfg|
            verify_envelope_requirements!(cfg)
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

          # Warm the cipher internals (sub-ciphers, parsed key material) in this
          # single-threaded phase so runtime encryption and decryption across worker threads
          # only read already-built state. Custom ciphers can opt in by exposing
          # #warmup(config)
          cipher = config.encryption.cipher
          cipher.warmup(config) if cipher.respond_to?(:warmup)
        end

        # This feature does not need any changes post-fork
        #
        # @param _config [Karafka::Core::Configurable::Node]
        # @param _pre_fork_producer [WaterDrop::Producer]
        def post_fork(_config, _pre_fork_producer)
          true
        end

        private

        # The envelope mode relies on the EVP PKey API (`PKey#encrypt`/`#decrypt` with an
        # options hash), available since the openssl gem 3.0. All supported Rubies bundle a
        # sufficient version as a default gem, but it can be pinned lower in a Gemfile, hence
        # this runtime constraint instead of a gemspec dependency that everyone would carry
        # for a single opt-in feature.
        #
        # @param config [Karafka::Core::Configurable::Node] root node config
        def verify_envelope_requirements!(config)
          return unless config.encryption.active
          return unless config.encryption.mode == :envelope
          return if Gem::Version.new(OpenSSL::VERSION) >= Gem::Version.new("3.0.0")

          raise(
            Karafka::Errors::DependencyConstraintsError,
            "encryption.mode = :envelope requires the openssl gem >= 3.0, " \
            "#{OpenSSL::VERSION} detected"
          )
        end
      end
    end
  end
end
