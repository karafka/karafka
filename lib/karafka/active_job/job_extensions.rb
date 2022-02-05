# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Allows for setting karafka specific options in ActiveJob jobs
    module JobExtensions
      # Defaults for Karafka specific ActiveJob options
      DEFAULTS = {
        # By default we dispatch with faster async method (non-blocking)
        dispatch_method: :produce_async
      }.freeze

      class << self
        # Defines all the needed accessors and sets defaults
        # @param klass [ActiveJob::Base] active job base
        def extended(klass)
          klass.class_attribute :_karafka_options
          klass._karafka_options = DEFAULTS.dup
        end
      end

      # @param args [Hash] additional options that allow for jobs Karafka related options
      #   customization
      # @return [Hash] karafka options
      def karafka_options(args = {})
        return _karafka_options if args.empty?

        args.each do |name, value|
          _karafka_options[name] = value
        end
      end
    end
  end
end
