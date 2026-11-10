# frozen_string_literal: true

module Karafka
  class Admin
    module Contracts
      # Contract for dead letter queue copy parameters
      class DeadLetterQueues < Karafka::Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("admin").fetch("dead_letter_queues")
        end

        required(:topic_name) { |val| val.is_a?(String) && !val.empty? }
        required(:target_topic_name) { |val| val.nil? || (val.is_a?(String) && !val.empty?) }
        required(:start_offset) { |val| val.is_a?(Time) || (val.is_a?(Integer) && val >= 0) }
        required(:end_offset) { |val| val.nil? || (val.is_a?(Integer) && val >= 0) }

        required(:partitions) do |val|
          next true if val.nil?
          next false unless val.is_a?(Array) && !val.empty?

          val.all? { |partition| partition.is_a?(Integer) && partition >= 0 } &&
            val.uniq.size == val.size
        end

        # Karafka.producer dispatches to the app cluster, not to the custom one
        virtual do |data, errors|
          next unless errors.empty?
          next unless data.fetch(:custom_kafka)
          next unless data.fetch(:producer).nil?

          [[%w[producer], :required_with_custom_kafka]]
        end
      end
    end
  end
end
