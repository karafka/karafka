# frozen_string_literal: true

# Checker for extracting and verifying error types handling across listeners
#
# This module scans the Karafka source code to extract all error types that are emitted
# via the instrumentation system and provides utilities to verify that listeners properly
# handle these error types.
module ErrorTypesChecker
  # Error types that are optional/pro-only or handled via the generic else clause in listeners
  # These don't require explicit case handlers as they're rare edge cases
  OPTIONAL_ERROR_TYPES = %w[
    callbacks.oauthbearer_token_refresh.error
    callbacks.rebalance.partitions_assign.error
    callbacks.rebalance.partitions_assigned.error
    callbacks.rebalance.partitions_revoke.error
    callbacks.rebalance.partitions_revoked.error
    recurring_tasks.task.execute.error
  ].freeze

  # Dynamic rebalance callback names that generate error types
  REBALANCE_CALLBACK_NAMES = %w[
    partitions_revoke
    partitions_assign
    partitions_revoked
    partitions_assigned
  ].freeze

  # Pattern to detect dynamic rebalance error type generation in source
  REBALANCE_ERROR_PATTERN = "callbacks.rebalance.#{name}.error"

  class << self
    # Extracts all error types from the Karafka lib source code
    #
    # @return [Array<String>] sorted list of unique error types found in source code
    # @note This scans for patterns like `type: 'something.error'` in the lib directory
    def extract_error_types_from_source
      lib_path = File.expand_path("../../lib", __dir__)
      error_types = Set.new

      # Scan all Ruby files in lib directory
      Dir.glob(File.join(lib_path, "**", "*.rb")).each do |file|
        content = File.read(file)

        # Match static error type definitions: type: 'something.error' or type: "something.error"
        content.scan(/type:\s*['"]([^'"]+\.error)['"]/).flatten.each do |type|
          # Skip dynamic patterns that contain interpolation markers
          next if type.include?("#")

          error_types << type
        end

        # Match dynamic error type definitions like: type: "callbacks.rebalance.#{name}.error"
        # These generate multiple error types based on the rebalance callback names
        next unless content.include?(REBALANCE_ERROR_PATTERN)

        REBALANCE_CALLBACK_NAMES.each do |name|
          error_types << "callbacks.rebalance.#{name}.error"
        end
      end

      error_types.to_a.sort
    end

    # Extracts error types handled by a listener from its case statement
    #
    # @param listener_class [Class] the listener class to analyze
    # @return [Array<String>] sorted list of error types handled by the listener
    def extract_handled_error_types(listener_class)
      # Get the source file for the listener
      source_file = listener_class.instance_method(:on_error_occurred).source_location&.first
      return [] unless source_file && File.exist?(source_file)

      content = File.read(source_file)
      error_types = Set.new

      # Extract error types from when clauses
      content.scan(/when\s+['"]([^'"]+\.error)['"]/).flatten.each do |type|
        error_types << type
      end

      error_types.to_a.sort
    end

    # Extracts consumer error types from a constant like USER_CONSUMER_ERROR_TYPES
    #
    # @param listener_class [Class] the listener class to check
    # @param constant_name [Symbol] name of the constant containing error types
    # @return [Array<String>] sorted list of error types from the constant
    def extract_constant_error_types(listener_class, constant_name)
      return [] unless listener_class.const_defined?(constant_name, false)

      listener_class.const_get(constant_name, false).to_a.sort
    end

    # Returns all consumer-related error types from the source
    #
    # @return [Array<String>] sorted list of consumer error types
    def consumer_error_types
      extract_error_types_from_source.select { |t| t.start_with?("consumer.") }.sort
    end

    # Checks if a listener handles all source-defined error types (for logging listeners)
    #
    # @param listener_class [Class] the listener class to check
    # @return [Hash] with :missing and :extra keys showing discrepancies
    def check_logging_listener_coverage(listener_class)
      source_types = extract_error_types_from_source
      handled_types = extract_handled_error_types(listener_class)

      # Remove optional error types that are handled via the generic else clause
      required_source_types = source_types - OPTIONAL_ERROR_TYPES

      {
        missing: (required_source_types - handled_types).sort,
        extra: (handled_types - source_types - OPTIONAL_ERROR_TYPES).sort
      }
    end

    # Checks if a metrics listener's consumer error types constant covers all consumer errors
    #
    # @param listener_class [Class] the listener class to check
    # @param constant_name [Symbol] name of the constant
    # @return [Hash] with :missing and :extra keys showing discrepancies
    def check_consumer_error_types_coverage(
      listener_class,
      constant_name = :USER_CONSUMER_ERROR_TYPES
    )
      source_consumer_types = consumer_error_types
      constant_types = extract_constant_error_types(listener_class, constant_name)

      {
        missing: (source_consumer_types - constant_types).sort,
        extra: (constant_types - source_consumer_types).sort
      }
    end
  end
end
