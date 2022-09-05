# frozen_string_literal: true

module Karafka
  module Routing
    # Proxy is used as a translation layer in between the DSL and raw topic and consumer group
    # objects.
    class Proxy
      attr_reader :target

      # @param target [Object] target object to which we proxy any DSL call
      # @param block [Proc] block that we want to evaluate in the proxy context
      def initialize(target, &block)
        @target = target
        instance_eval(&block)
      end

      # Translates the no "=" DSL of routing into elements assignments on target
      # @param method_name [Symbol] name of the missing method
      def method_missing(method_name, ...)
        return super unless respond_to_missing?(method_name)

        if @target.respond_to?(:"#{method_name}=")
          @target.public_send(:"#{method_name}=", ...)
        else
          @target.public_send(method_name, ...)
        end
      end

      # Tells whether or not a given element exists on the target
      # @param method_name [Symbol] name of the missing method
      # @param include_private [Boolean] should we include private in the check as well
      def respond_to_missing?(method_name, include_private = false)
        @target.respond_to?(:"#{method_name}=", include_private) ||
          @target.respond_to?(method_name, include_private) ||
          super
      end
    end
  end
end
