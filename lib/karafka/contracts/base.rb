# frozen_string_literal: true

module Karafka
  module Contracts
    # Base contract for all Karafka contracts
    class Base < ::Karafka::Core::Contractable::Contract
      # @param data [Hash] data for validation
      # @param scope [Array<String>] nested scope if in use
      # @return [Boolean] true if all good
      # @raise [Errors::InvalidConfigurationError] invalid configuration error
      # @note We use contracts only in the config validation context, so no need to add support
      #   for multiple error classes. It will be added when it will be needed.
      def validate!(data, scope: [])
        super(data, Errors::InvalidConfigurationError, scope: scope)
      end
    end
  end
end
