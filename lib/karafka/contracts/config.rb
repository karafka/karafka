# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract with validation rules for Karafka configuration details.
    #
    # @note There are many more configuration options inside of the
    #   `Karafka::Setup::Config` model, but we don't validate them here as they are
    #   validated per each route (topic + consumer_group) because they can be overwritten,
    #   so we validate all of that once all the routes are defined and ready.
    class Config < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('config')
      end

      # License validity happens in the licenser. Here we do only the simple consistency checks
      nested(:license) do
        required(:token) { |val| [true, false].include?(val) || val.is_a?(String) }
        required(:entity) { |val| val.is_a?(String) }
      end

      required(:client_id) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:concurrency) { |val| val.is_a?(Integer) && val.positive? }
      required(:consumer_mapper) { |val| !val.nil? }
      required(:consumer_persistence) { |val| [true, false].include?(val) }
      required(:pause_timeout) { |val| val.is_a?(Integer) && val.positive? }
      required(:pause_max_timeout) { |val| val.is_a?(Integer) && val.positive? }
      required(:pause_with_exponential_backoff) { |val| [true, false].include?(val) }
      required(:shutdown_timeout) { |val| val.is_a?(Integer) && val.positive? }
      required(:max_wait_time) { |val| val.is_a?(Integer) && val.positive? }
      required(:kafka) { |val| val.is_a?(Hash) && !val.empty? }

      # We validate internals just to be sure, that they are present and working
      nested(:internal) do
        required(:status) { |val| !val.nil? }
        required(:process) { |val| !val.nil? }

        nested(:routing) do
          required(:builder) { |val| !val.nil? }
          required(:subscription_groups_builder) { |val| !val.nil? }
        end

        nested(:processing) do
          required(:jobs_builder) { |val| !val.nil? }
          required(:scheduler) { |val| !val.nil? }
          required(:coordinator_class) { |val| !val.nil? }
          required(:partitioner_class) { |val| !val.nil? }
        end

        nested(:active_job) do
          required(:dispatcher) { |val| !val.nil? }
          required(:job_options_contract) { |val| !val.nil? }
          required(:consumer_class) { |val| !val.nil? }
        end
      end

      virtual do |data, errors|
        next unless errors.empty?

        detected_errors = []

        data.fetch(:kafka).each_key do |key|
          next if key.is_a?(Symbol)

          detected_errors << [[:kafka, key], :key_must_be_a_symbol]
        end

        detected_errors
      end

      virtual do |data, errors|
        next unless errors.empty?

        pause_timeout = data.fetch(:pause_timeout)
        pause_max_timeout = data.fetch(:pause_max_timeout)

        next if pause_timeout <= pause_max_timeout

        [[%i[pause_timeout], :max_timeout_vs_pause_max_timeout]]
      end

      virtual do |data, errors|
        next unless errors.empty?

        shutdown_timeout = data.fetch(:shutdown_timeout)
        max_wait_time = data.fetch(:max_wait_time)

        next if max_wait_time < shutdown_timeout

        [[%i[shutdown_timeout], :shutdown_timeout_vs_max_wait_time]]
      end
    end
  end
end
