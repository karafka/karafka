# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Encryption
      # Encryption related contracts
      module Contracts
        # Makes sure, all the expected config is defined as it should be
        class Config < Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
            ).fetch("en").fetch("validations").fetch("setup").fetch("config")
          end

          nested(:encryption) do
            required(:active) { |val| [true, false].include?(val) }
            required(:version) { |val| val.is_a?(String) && !val.empty? }
            required(:public_key) { |val| val.is_a?(String) }
            required(:fingerprinter) { |val| val == false || val.respond_to?(:hexdigest) }

            required(:private_keys) do |val|
              val.is_a?(Hash) &&
                val.keys.all?(String) &&
                val.values.all?(String)
            end
          end

          # Public key validation
          virtual do |data, errors|
            next unless errors.empty?
            next unless data.fetch(:encryption).fetch(:active)

            key = OpenSSL::PKey::RSA.new(data.fetch(:encryption).fetch(:public_key))

            next unless key.private?

            [[%i[encryption public_key], :needs_to_be_public]]
          rescue OpenSSL::PKey::RSAError
            [[%i[encryption public_key], :invalid]]
          end

          # Private keys validation
          virtual do |data, errors|
            next unless errors.empty?
            next unless data.fetch(:encryption).fetch(:active)

            private_keys = data.fetch(:encryption).fetch(:private_keys)

            # Keys may be empty for production only envs
            next if private_keys.empty?

            keys = private_keys.each_value.map do |key|
              OpenSSL::PKey::RSA.new(key)
            end

            next if keys.all?(&:private?)

            [[%i[encryption private_keys], :need_to_be_private]]
          rescue OpenSSL::PKey::RSAError
            [[%i[encryption private_keys], :invalid]]
          end
        end
      end
    end
  end
end
