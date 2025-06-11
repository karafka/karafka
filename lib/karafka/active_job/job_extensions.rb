# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Allows for setting karafka specific options in ActiveJob jobs
    module JobExtensions
      class << self
        # Defines all the needed accessors and sets defaults
        # @param klass [ActiveJob::Base] active job base
        def extended(klass)
          klass.class_attribute :_karafka_options
          klass._karafka_options = {}
        end
      end

      # @param new_options [Hash] additional options that allow for jobs Karafka related options
      #   customization
      # @return [Hash] karafka options
      def karafka_options(new_options = {})
        return _karafka_options if new_options.empty?

        # Make sure, that karafka options that someone wants to use are valid before assigning
        # them
        App.config.internal.active_job.job_options_contract.validate!(
          new_options,
          scope: %w[active_job]
        )

        # We need to modify this hash because otherwise we would modify parent hash.
        self._karafka_options = _karafka_options.dup

        new_options.each do |name, value|
          _karafka_options[name] = value
        end

        _karafka_options
      end
    end
  end
end
