# frozen_string_literal: true

module Karafka
  module Routing
    # Proxy is used as a translation layer in between the DSL and raw topic and consumer group
    # objects.
    class Proxy
      # Non-writer DSL methods that set a target setting when called with any non-nil argument. Like
      # writers, a call in the block is not overwritten by the same call in the defaults.
      SETTING_METHODS = %i[pause].freeze

      private_constant :SETTING_METHODS

      attr_reader :target

      # @param target [Object] target object to which we proxy any DSL call
      # @param defaults [Proc, nil] defaults for target that should be applicable after the proper
      #   proxy context (if needed) or nil when none apply. They do not overwrite settings assigned
      #   in the block.
      # @param block [Proc, nil] block that we want to evaluate in the proxy context or nil if no
      #   proxy block context for example because whole context is taken from defaults
      def initialize(target, defaults = ->(_) {}, &block)
        @target = target
        @assigned = Set.new
        @applying_defaults = false
        instance_eval(&block) if block
        @applying_defaults = true
        instance_eval(&defaults) if defaults
      end

      # Translates the no "=" DSL of routing into elements assignments on target
      # @param method_name [Symbol] name of the missing method
      def method_missing(method_name, ...)
        return super unless respond_to_missing?(method_name)

        writer = @target.respond_to?(:"#{method_name}=")

        if writer || (SETTING_METHODS.include?(method_name) && setting_call?(...))
          if @applying_defaults
            return if @assigned.include?(method_name)
          else
            @assigned << method_name
          end
        end

        if writer
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

      private

      # @param args [Array<Object>] positional arguments of the DSL call
      # @param kwargs [Hash] keyword arguments of the DSL call
      # @option kwargs [Object] :name any keyword argument the target method accepts
      # @return [Boolean] true when the call has any non-nil argument, so it sets a value
      def setting_call?(*args, **kwargs)
        args.any? { |arg| !arg.nil? } || kwargs.any? { |_, value| !value.nil? }
      end
    end
  end
end
