# frozen_string_literal: true

module Karafka
  module Contracts
    class Base < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      # @param data [Hash] data for validation
      # @return [Boolean] true if all good
      # @raise [Errors::InvalidConfigurationError] invalid configuration error
      def validate!(data)
        result = call(data)

        return true if result.success?

        raise Errors::InvalidConfigurationError, result.errors.to_h
      end
    end
  end
end
