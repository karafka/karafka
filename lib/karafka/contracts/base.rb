# frozen_string_literal: true

module Karafka
  module Contracts
    # Base contract for all Karafka contracts
    class Base < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      # @param data [Hash] data for validation
      # @return [Boolean] true if all good
      # @raise [Errors::InvalidConfigurationError] invalid configuration error
      # @note We use contracts only in the config validation context, so no need to add support
      #   for multiple error classes. It will be added when it will be needed.
      def validate!(data)
        result = call(data)

        return true if result.success?

        raise Errors::InvalidConfigurationError, result.errors.to_h
      end
    end
  end
end
