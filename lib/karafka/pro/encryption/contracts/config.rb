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
    module Encryption
      # Encryption related contracts
      module Contracts
        # Makes sure, all the expected config is defined as it should be
        class Config < ::Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load(
              File.read(
                File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
              )
            ).fetch('en').fetch('validations').fetch('config')
          end

          nested(:encryption) do
            required(:active) { |val| [true, false].include?(val) }
            required(:version) { |val| val.is_a?(String) && !val.empty? }
            required(:public_key) { |val| val.is_a?(String) }

            required(:private_keys) do |val|
              val.is_a?(Hash) &&
                val.keys.all? { |key| key.is_a?(String) } &&
                val.values.all? { |key| key.is_a?(String) }
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
