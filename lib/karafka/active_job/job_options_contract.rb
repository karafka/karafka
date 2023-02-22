# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Contract for validating the options that can be altered with `#karafka_options` per job class
    # @note We keep this in the `Karafka::ActiveJob` namespace instead of `Karafka::Contracts` as
    #   we want to keep ActiveJob related Karafka components outside of the core Karafka code and
    #   all in the same place
    class JobOptionsContract < Contracts::Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('job_options')
      end

      optional(:dispatch_method) do |val|
        %i[
          produce_async
          produce_sync
        ].include?(val)
      end
      optional(:dispatch_many_method) do |val|
        %i[
          produce_many_async
          produce_many_sync
        ].include?(val)
      end
    end
  end
end
