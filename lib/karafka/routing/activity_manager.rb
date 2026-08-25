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

      # Characters that, when present in an include/exclude value, mark it as a wildcard
      # pattern instead of a literal name
      WILDCARD_CHARACTERS = /[*?\[\]]/

      class << self
        # @param value [String] name or pattern used in an include/exclude filter
        # @return [Boolean] true if the value is a wildcard pattern and not a literal name
        # @note Only `String` values can be wildcard patterns. Non-string entries (e.g. an
        #   array accidentally passed as a single name) are always treated as literals so they
        #   never reach `File.fnmatch?`, which only accepts strings.
        def wildcard?(value)
          value.is_a?(::String) && value.match?(WILDCARD_CHARACTERS)
        end
      end

      # Initializes the activity manager with empty inclusion and exclusion lists
      def initialize
        @included = Hash.new { |h, k| h[k] = [] }
        @excluded = Hash.new { |h, k| h[k] = [] }
      end

      # Adds resource to included/active
      # @param type [Symbol] type for inclusion
      # @param name [String] name of the element or a wildcard pattern (e.g. `"app-a-*"`)
      def include(type, name)
        validate!(type)

        @included[type] << name
      end

      # Adds resource to excluded
      # @param type [Symbol] type for inclusion
      # @param name [String] name of the element or a wildcard pattern (e.g. `"app-a-*"`)
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
        return true if !included.empty? && matches?(included, name)

        # If there are exclusions but our is not excluded and no inclusions or included, it's ok
        !excluded.empty? &&
          !matches?(excluded, name) &&
          (included.empty? || matches?(included, name))
      end

      # @return [Hash] accumulated data in a hash for validations
      def to_h
        (
          SUPPORTED_TYPES.map { |type| [:"include_#{type}", @included[type]] } +
          SUPPORTED_TYPES.map { |type| [:"exclude_#{type}", @excluded[type]] }
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

      # @param patterns [Array<String>] literal names and/or wildcard patterns
      # @param name [String] name to match against the patterns
      # @return [Boolean] true if any of the patterns matches the name, either literally or
      #   as a wildcard
      # @note Only string wildcard patterns are matched via `File.fnmatch?`. Any other entry
      #   (a literal name or a non-string value) is compared with plain equality, which keeps
      #   the pre-wildcard behavior and avoids passing non-strings into `File.fnmatch?`.
      def matches?(patterns, name)
        patterns.any? do |pattern|
          if self.class.wildcard?(pattern)
            File.fnmatch?(pattern, name, File::FNM_EXTGLOB)
          else
            pattern == name
          end
        end
      end
    end
  end
end
