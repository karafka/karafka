# frozen_string_literal: true

module Karafka
  module Routing
    # Proxy is used as a translation layer in between the DSL and raw topic and consumer group
    # objects.
    class Proxy
      attr_reader :target

      # We should proxy only non ? and = methods as we want to have a regular dsl
      IGNORED_POSTFIXES = %w[
        ?
        =
        !
      ].freeze

      private_constant :IGNORED_POSTFIXES

      # @param target [Object] target object to which we proxy any DSL call
      # @param block [Proc] block that we want to evaluate in the proxy context
      def initialize(target, &block)
        @target = target
        instance_eval(&block)
      end

      # Translates the no "=" DSL of routing into elements assignments on target
      # @param method_name [Symbol] name of the missing method
      # @param arguments [Array] array with it's arguments
      # @param block [Proc] block provided to the method
      def method_missing(method_name, *arguments, &block)
        return super unless respond_to_missing?(method_name)

        @target.public_send(:"#{method_name}=", *arguments, &block)
      end

      # Tells whether or not a given element exists on the target
      # @param method_name [Symbol] name of the missing method
      # @param include_private [Boolean] should we include private in the check as well
      def respond_to_missing?(method_name, include_private = false)
        return false if IGNORED_POSTFIXES.any? { |postfix| method_name.to_s.end_with?(postfix) }

        @target.respond_to?(:"#{method_name}=", include_private) || super
      end
    end
  end
end
