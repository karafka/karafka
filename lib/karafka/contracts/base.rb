# frozen_string_literal: true

module Karafka
  module Contracts
    class Base < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      # @param data [Hash] data for validation
      # @param error_class [Class] error class that should be used when validation fails
      # @return [Boolean] true
      # @raise [StandardError] any error provided in the error_class that inherits from the
      #   standard error
      def validate!(data, error_class)
        result = call(data)

        return true if result.success?

        raise error_class, result.errors.to_h
      end
    end
  end
end
