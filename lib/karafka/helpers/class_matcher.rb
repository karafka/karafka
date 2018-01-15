# frozen_string_literal: true

module Karafka
  module Helpers
    # Class used to autodetect corresponding classes that are internally inside Karafka framework
    # It is used among others to match:
    #   consumer => responder
    class ClassMatcher
      # Regexp used to remove any non classy like characters that might be in the consumer
      # class name (if defined dynamically, etc)
      CONSTANT_REGEXP = %r{[?!=+\-\*/\^\|&\[\]<>%~\#\:\s\(\)]}

      # @param klass [Class] class to which we want to find a corresponding class
      # @param from [String] what type of object is it (based on postfix name part)
      # @param to [String] what are we looking for (based on a postfix name part)
      # @example Consumer that has a corresponding responder
      #   matcher = Karafka::Helpers::ClassMatcher.new(SuperConsumer, 'Consumer', 'Responder')
      #   matcher.match #=> SuperResponder
      # @example Consumer without a corresponding responder
      #   matcher = Karafka::Helpers::ClassMatcher.new(Super2Consumer, 'Consumer', 'Responder')
      #   matcher.match #=> nil
      def initialize(klass, from:, to:)
        @klass = klass
        @from = from
        @to = to
      end

      # @return [Class] matched class
      # @return [nil] nil if we couldn't find matching class
      def match
        return nil if name.empty?
        return nil unless scope.const_defined?(name)
        matching = scope.const_get(name)
        same_scope?(matching) ? matching : nil
      end

      # @return [String] name of a new class that we're looking for
      # @note This method returns name of a class without a namespace
      # @example From SuperConsumer matching responder
      #   matcher.name #=> 'SuperResponder'
      # @example From Namespaced::Super2Consumer matching responder
      #   matcher.name #=> Super2Responder
      def name
        inflected = @klass.to_s.split('::').last.to_s
        inflected.gsub!(@from, @to)
        inflected.gsub!(CONSTANT_REGEXP, '')
        inflected
      end

      # @return [Class, Module] class or module in which we're looking for a matching
      def scope
        scope_of(@klass)
      end

      private

      # @param klass [Class] class for which we want to extract it's enclosing class/module
      # @return [Class, Module] enclosing class/module
      # @return [::Object] object if it was a root class
      #
      # @example Non-namespaced class
      #   scope_of(SuperClass) #=> Object
      # @example Namespaced class
      #   scope_of(Abc::SuperClass) #=> Abc
      def scope_of(klass)
        enclosing = klass.to_s.split('::')[0...-1]
        return ::Object if enclosing.empty?
        ::Object.const_get(enclosing.join('::'))
      end

      # @param matching [Class] class of which scope we want to check
      # @return [Boolean] true if the scope of class is the same as scope of matching
      def same_scope?(matching)
        scope == scope_of(matching)
      end
    end
  end
end
