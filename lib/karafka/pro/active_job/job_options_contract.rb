# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ActiveJob
      # Contract for validating the options that can be altered with `#karafka_options` per job
      # class that works with Pro features.
      class JobOptionsContract < Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load(
            File.read(
              File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
            )
          ).fetch('en').fetch('validations').fetch('job_options')
        end

        optional(:producer) { |val| val.nil? || val.respond_to?(:call) }
        optional(:partitioner) { |val| val.respond_to?(:call) }
        optional(:partition_key_type) { |val| %i[key partition_key partition].include?(val) }

        # Whether this is a legit scheduled messages topic will be validated during the first
        # dispatch, so we do not repeat validations here
        optional(:scheduled_messages_topic) do |val|
          (val.is_a?(String) || val.is_a?(Symbol)) &&
            ::Karafka::Contracts::TOPIC_REGEXP.match?(val.to_s)
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
end
