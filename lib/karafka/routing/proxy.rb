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

      # @param target [Object] target object to which we proxy any DSL call
      # @yield Evaluates block in the proxy context
      def initialize(target, &block)
        @target = target
        instance_eval(&block)
      end

      # Translates the no "=" DSL of routing into elements assignments on target
      def method_missing(method_name, *arguments, &block)
        return super unless respond_to_missing?(method_name)
        @target.public_send(:"#{method_name}=", *arguments, &block)
      end

      # Tells whether or not a given element exists on the target
      def respond_to_missing?(method_name, include_private = false)
        return false if IGNORED_POSTFIXES.any? { |postfix| method_name.to_s.end_with?(postfix) }
        @target.respond_to?(:"#{method_name}=", include_private) || super
      end
    end
  end
end
