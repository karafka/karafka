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
        required(:token) { |token| [true, false].include?(token) || token.is_a?(String) }
        required(:entity) { |entity| entity.is_a?(String) }
        required(:expires_on) { |eo| eo.is_a?(Date) }
      end

      required(:client_id) { |cid| cid.is_a?(String) && Contracts::TOPIC_REGEXP.match?(cid) }
      required(:concurrency) { |con| con.is_a?(Integer) && con.positive? }
      required(:consumer_mapper) { |consumer_mapper| !consumer_mapper.nil? }
      required(:consumer_persistence) { |con_pre| [true, false].include?(con_pre) }
      required(:pause_timeout) { |pt| pt.is_a?(Integer) && pt > 0 }
      required(:pause_max_timeout) { |pmt| pmt.is_a?(Integer) && pmt > 0 }
      required(:pause_with_exponential_backoff) { |pweb| [true, false].include?(pweb) }
      required(:shutdown_timeout) { |st| st.is_a?(Integer) && st > 0 }
      required(:max_wait_time) { |mwt| mwt.is_a?(Integer) && mwt > 0 }
      required(:kafka) { |kafka| kafka.is_a?(Hash) && !kafka.empty? }

      # We validate internals just to be sure, that they are present and working
      nested(:internal) do
        required(:status) { |status| !status.nil? }
        required(:process) { |process| !process.nil? }

        nested(:routing) do
          required(:builder) { |builder| !builder.nil? }
          required(:subscription_groups_builder) { |sg| !sg.nil? }
        end

        nested(:processing) do
          required(:jobs_builder) { |jobs_builder| !jobs_builder.nil? }
          required(:scheduler) { |scheduler| !scheduler.nil? }
          required(:coordinator_class) { |coordinator_class| !coordinator_class.nil? }
          required(:partitioner_class) { |partitioner_class| !partitioner_class.nil? }
        end

         nested(:active_job) do
           required(:dispatcher) { |dispatcher| !dispatcher.nil? }
           required(:job_options_contract) { |job_options_contract| !job_options_contract.nil? }
           required(:consumer_class) { |consumer_class| !consumer_class.nil? }
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
