# frozen_string_literal: true

module Karafka
  module Routing
    class Proxy
      attr_reader :target

      def initialize(target, &block)
        @target = target
        instance_eval(&block)
      end

      def method_missing(method_name, *arguments, &block)
        @target.public_send(:"#{method_name}=", *arguments, &block)
      end

      def respond_to_missing?(method_name, include_private = false)
        @target.respond_to?(:"#{method_name}=") || super
      end
    end
  end
end
