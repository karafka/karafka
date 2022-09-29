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

      # Ruby 2.7.0 to 2.7.2 do not have arg forwarding, so we fallback to the old way
      arg_forwarding = RUBY_VERSION < '3.0' ? '*args, &block' : '...'

      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        # Translates the no "=" DSL of routing into elements assignments on target
        # @param method_name [Symbol] name of the missing method
        def method_missing(method_name, #{arg_forwarding})
          return super unless respond_to_missing?(method_name)

          if @target.respond_to?(:"\#{method_name}=")
            @target.public_send(:"\#{method_name}=", #{arg_forwarding})
          else
            @target.public_send(method_name, #{arg_forwarding})
          end
        end
      RUBY

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
