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
            File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
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
      required(:consumer_persistence) { |val| [true, false].include?(val) }
      required(:pause_timeout) { |val| val.is_a?(Integer) && val.positive? }
      required(:pause_max_timeout) { |val| val.is_a?(Integer) && val.positive? }
      required(:pause_with_exponential_backoff) { |val| [true, false].include?(val) }
      required(:strict_topics_namespacing) { |val| [true, false].include?(val) }
      required(:shutdown_timeout) { |val| val.is_a?(Integer) && val.positive? }
      required(:max_wait_time) { |val| val.is_a?(Integer) && val.positive? }
      required(:group_id) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:kafka) { |val| val.is_a?(Hash) && !val.empty? }
      required(:strict_declarative_topics) { |val| [true, false].include?(val) }
      required(:worker_thread_priority) { |val| (-3..3).to_a.include?(val) }

      nested(:swarm) do
        required(:nodes) { |val| val.is_a?(Integer) && val.positive? }
        required(:node) { |val| val == false || val.is_a?(Karafka::Swarm::Node) }
      end

      nested(:oauth) do
        required(:token_provider_listener) do |val|
          val == false || val.respond_to?(:on_oauthbearer_token_refresh)
        end
      end

      nested(:admin) do
        # Can be empty because inherits values from the root kafka
        required(:kafka) { |val| val.is_a?(Hash) }
        required(:group_id) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
        required(:max_wait_time) { |val| val.is_a?(Integer) && val.positive? }
        required(:retry_backoff) { |val| val.is_a?(Integer) && val >= 100 }
        required(:max_retries_duration) { |val| val.is_a?(Integer) && val >= 1_000 }
      end

      # We validate internals just to be sure, that they are present and working
      nested(:internal) do
        required(:status) { |val| !val.nil? }
        required(:process) { |val| !val.nil? }
        # In theory this could be less than a second, however this would impact the maximum time
        # of a single consumer queue poll, hence we prevent it
        required(:tick_interval) { |val| val.is_a?(Integer) && val >= 1_000 }
        required(:supervision_sleep) { |val| val.is_a?(Numeric) && val.positive? }
        required(:forceful_exit_code) { |val| val.is_a?(Integer) && val >= 0 }

        nested(:swarm) do
          required(:manager) { |val| !val.nil? }
          required(:orphaned_exit_code) { |val| val.is_a?(Integer) && val >= 0 }
          required(:pidfd_open_syscall) { |val| val.is_a?(Integer) && val >= 0 }
          required(:pidfd_signal_syscall) { |val| val.is_a?(Integer) && val >= 0 }
          required(:supervision_interval) { |val| val.is_a?(Integer) && val >= 1_000 }
          required(:liveness_interval) { |val| val.is_a?(Integer) && val >= 1_000 }
          required(:liveness_listener) { |val| !val.nil? }
          required(:node_report_timeout) { |val| val.is_a?(Integer) && val >= 1_000 }
          required(:node_restart_timeout) { |val| val.is_a?(Integer) && val >= 1_000 }
        end

        nested(:connection) do
          required(:manager) { |val| !val.nil? }
          required(:conductor) { |val| !val.nil? }
          required(:reset_backoff) { |val| val.is_a?(Integer) && val >= 1_000 }
          required(:listener_thread_priority) { |val| (-3..3).to_a.include?(val) }

          nested(:proxy) do
            nested(:commit) do
              required(:max_attempts) { |val| val.is_a?(Integer) && val.positive? }
              required(:wait_time) { |val| val.is_a?(Integer) && val.positive? }
            end

            # All of them have the same requirements
            %i[
              query_watermark_offsets
              offsets_for_times
              committed
              metadata
            ].each do |scope|
              nested(scope) do
                required(:timeout) { |val| val.is_a?(Integer) && val.positive? }
                required(:max_attempts) { |val| val.is_a?(Integer) && val.positive? }
                required(:wait_time) { |val| val.is_a?(Integer) && val.positive? }
              end
            end
          end
        end

        nested(:routing) do
          required(:builder) { |val| !val.nil? }
          required(:subscription_groups_builder) { |val| !val.nil? }
        end

        nested(:processing) do
          required(:jobs_builder) { |val| !val.nil? }
          required(:jobs_queue_class) { |val| !val.nil? }
          required(:scheduler_class) { |val| !val.nil? }
          required(:coordinator_class) { |val| !val.nil? }
          required(:errors_tracker_class) { |val| val.nil? || val.is_a?(Class) }
          required(:partitioner_class) { |val| !val.nil? }
          required(:strategy_selector) { |val| !val.nil? }
          required(:expansions_selector) { |val| !val.nil? }
          required(:executor_class) { |val| !val.nil? }
          required(:worker_job_call_wrapper) { |val| val == false || val.respond_to?(:wrap) }
        end

        nested(:active_job) do
          required(:dispatcher) { |val| !val.nil? }
          required(:job_options_contract) { |val| !val.nil? }
          required(:consumer_class) { |val| !val.nil? }
        end
      end

      # Ensure all root kafka keys are symbols
      virtual do |data, errors|
        next unless errors.empty?

        detected_errors = []

        data.fetch(:kafka).each_key do |key|
          next if key.is_a?(Symbol)

          detected_errors << [[:kafka, key], :key_must_be_a_symbol]
        end

        detected_errors
      end

      # Ensure all admin kafka keys are symbols
      virtual do |data, errors|
        next unless errors.empty?

        detected_errors = []

        data.fetch(:admin).fetch(:kafka).each_key do |key|
          next if key.is_a?(Symbol)

          detected_errors << [[:admin, :kafka, key], :key_must_be_a_symbol]
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

      # `internal.swarm.node_report_timeout` should not be close to `max_wait_time` otherwise
      # there may be a case where node cannot report often enough because it is clogged by waiting
      # on more data.
      #
      # We handle that at a config level to make sure that this is correctly configured.
      #
      # We do not validate this in the context of swarm usage (validate only if...) because it is
      # often that swarm only runs on prod and we do not want to crash it surprisingly.
      virtual do |data, errors|
        next unless errors.empty?

        max_wait_time = data.fetch(:max_wait_time)
        node_report_timeout = data.fetch(:internal)[:swarm][:node_report_timeout] || false

        next unless node_report_timeout
        # max wait time should be at least 20% smaller than the reporting time to have enough
        # time for reporting
        next if max_wait_time < node_report_timeout * 0.8

        [[%i[max_wait_time], :max_wait_time_vs_swarm_node_report_timeout]]
      end
    end
  end
end
