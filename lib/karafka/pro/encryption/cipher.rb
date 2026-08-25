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
    module Encryption
      # Cipher for encrypting and decrypting data
      #
      # A facade over the cipher implementations in {Ciphers}:
      #
      # - {Ciphers::Direct} (default) - legacy scheme with the payload RSA-encrypted directly,
      #   limited to payloads smaller than the RSA key capacity
      # - {Ciphers::Envelope} - hybrid scheme with a one-time AES-256-GCM key per payload,
      #   supporting payloads of any size
      #
      # Encryption follows the `encryption.mode` setting. Decryption is mode-independent: the
      # format is recognized per message (a valid direct RSA ciphertext is always exactly the
      # key modulus size, while an envelope is always at least 29 bytes longer), so consumers
      # decrypt both formats transparently regardless of the configured mode, making staged
      # producer-side rollout of the envelope mode safe.
      #
      # Format detection is deliberately payload-based rather than header-based, even though
      # the encryption middleware already writes message headers that could carry a format
      # marker. A header marker would remove the truncation blind spot documented on
      # {Ciphers::Direct#owns?}, but the payload would stop being self-describing: it must
      # remain decryptable also when it leaves Kafka through channels that do not preserve
      # headers (mirroring and replication tools, dumps, storage sinks) and when handled by
      # custom parsers or ciphers that only receive the payload through the stable
      # `#decrypt(version, content)` contract. We accept the blind spot as the cheaper cost.
      class Cipher
        include Helpers::ConfigImporter.new(
          encryption: %i[encryption]
        )

        # Encrypts given string content according to the configured `encryption.mode`
        # @param content [String]
        # @return [String]
        def encrypt(content)
          (encryption.mode == :envelope) ? envelope.encrypt(content) : direct.encrypt(content)
        end

        # Decrypts provided content using `version` key with the cipher implementation that
        # recognizes the content format, independently of the configured mode
        # @param version [String] encryption version
        # @param content [String] encrypted content
        # @return [String] decrypted content
        def decrypt(version, content)
          if direct.owns?(version, content)
            direct.decrypt(version, content)
          else
            envelope.decrypt(version, content)
          end
        end

        # Eagerly builds the underlying ciphers and parses the key material of the given
        # config. Invoked during the single-threaded setup phase so that runtime encryption
        # and decryption only read already-built, effectively frozen state and the lazy
        # initialization below never races across worker threads.
        #
        # @param root_config [Karafka::Core::Configurable::Node] config whose key material to
        #   warm. During setup this is the same app config the ciphers read at runtime.
        def warmup(root_config)
          direct.warmup(root_config.encryption)
          envelope.warmup(root_config.encryption)
        end

        private

        # Lazily built so this facade can be instantiated as a config default while the cipher
        # implementation files may not be loaded yet
        # @return [Ciphers::Direct]
        def direct
          @direct ||= Ciphers::Direct.new
        end

        # @return [Ciphers::Envelope]
        def envelope
          @envelope ||= Ciphers::Envelope.new
        end
      end
    end
  end
end
