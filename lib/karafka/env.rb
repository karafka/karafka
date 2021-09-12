# frozen_string_literal: true

module Karafka
  # Env management class to get and set environment for Karafka
  class Env < String
    # Keys where we look for environment details for Karafka
    LOOKUP_ENV_KEYS = %w[
      KARAFKA_ENV
      RACK_ENV
      RAILS_ENV
    ].freeze

    # Default fallback env
    DEFAULT_ENV = 'development'

    private_constant :LOOKUP_ENV_KEYS, :DEFAULT_ENV

    # @return [Karafka::Env] env object
    # @note Will load appropriate environment automatically
    def initialize
      super('')

      LOOKUP_ENV_KEYS
        .map { |key| ENV[key] }
        .compact
        .first
        .then { |env| env || DEFAULT_ENV }
        .then { |env| replace(env) }
    end

    # @param method_name [String] method name
    # @param include_private [Boolean] should we include private methods as well
    # @return [Boolean] true if we respond to a given missing method, otherwise false
    def respond_to_missing?(method_name, include_private = false)
      (method_name[-1] == '?') || super
    end

    # Reacts to missing methods, from which some might be the env checks.
    # If the method ends with '?' we assume, that it is an env check
    # @param method_name [String] method name for missing or env name with question mark
    # @param arguments [Array] any arguments that we pass to the method
    def method_missing(method_name, *arguments)
      method_name[-1] == '?' ? self == method_name[0..-2] : super
    end
  end
end
