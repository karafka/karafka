module Karafka
  # Concerns module
  module Concerns
    # module for defining before action implementation
    module BeforeAction
      # rubocop:disable all
      @@blocks = []
      @@methods = []
      # rubocop:enable all

      # before action method
      def before_action(*names, &block)
        @@blocks << block if block_given?
        @@methods << names unless names.empty?
      end

      # Invoked as a callback whenever an instance method is added to the receiver.
      def method_added(name)
        return if @filtering
        return if %i(initialize params params=).include? name
        return if (@@methods.flatten.to_a).include?(name)
        redefine_method(name)
      end

      # Calls all before actions before method. Does not invoke original method once
      # one of the before_actions returns false.
      def redefine_method(name)
        @filtering = true
        alias_method :"original_#{name}", name

        define_method name do |*args|
          result = @@blocks.inject(true) { |a, e| a && instance_eval(&e) } &&
            @@methods.flatten.to_a.inject(true) { |a, e| a && send(e) }
          send :"original_#{name}", *args if result
        end
        @filtering = false
      end
    end
  end
end
