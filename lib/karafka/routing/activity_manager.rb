# frozen_string_literal: true

module Karafka
  module Routing
    # Allows us to get track of which consumer groups, subscription groups and topics are enabled
    # or disabled via CLI
    class ActivityManager
      # Supported types of inclusions and exclusions
      SUPPORTED_TYPES = %i[
        consumer_groups
        subscription_groups
        topics
      ].freeze

      def initialize
        @included = Hash.new { |h, k| h[k] = [] }
        @excluded = Hash.new { |h, k| h[k] = [] }
      end

      # Adds resource to included/active
      # @param type [Symbol] type for inclusion
      # @param name [String] name of the element
      def include(type, name)
        validate!(type)

        @included[type] << name
      end

      # Adds resource to excluded
      # @param type [Symbol] type for inclusion
      # @param name [String] name of the element
      def exclude(type, name)
        validate!(type)

        @excluded[type] << name
      end

      # @param type [Symbol] type for inclusion
      # @param name [String] name of the element
      # @return [Boolean] is the given resource active or not
      def active?(type, name)
        validate!(type)

        included = @included[type]
        excluded = @excluded[type]

        # If nothing defined, all active by default
        return true if included.empty? && excluded.empty?
        # Inclusion supersedes exclusion in case someone wrote both
        return true if !included.empty? && included.include?(name)

        # If there are exclusions but our is not excluded and no inclusions or included, it's ok
        !excluded.empty? &&
          !excluded.include?(name) &&
          (included.empty? || included.include?(name))
      end

      # @return [Hash] accumulated data in a hash for validations
      def to_h
        (
          SUPPORTED_TYPES.map { |type| ["include_#{type}".to_sym, @included[type]] } +
          SUPPORTED_TYPES.map { |type| ["exclude_#{type}".to_sym, @excluded[type]] }
        ).to_h
      end

      # Clears the manager
      def clear
        @included.clear
        @excluded.clear
      end

      private

      # Checks if the type we want to register is supported
      #
      # @param type [Symbol] type for inclusion
      def validate!(type)
        return if SUPPORTED_TYPES.include?(type)

        raise(::Karafka::Errors::UnsupportedCaseError, type)
      end
    end
  end
end
