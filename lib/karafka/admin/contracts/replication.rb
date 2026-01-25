# frozen_string_literal: true

module Karafka
  class Admin
    # Contracts namespace for Admin validation logic
    module Contracts
      # Contract for replication plan parameters
      class Replication < Karafka::Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("admin").fetch("replication")
        end

        required(:topic) { |val| val.is_a?(String) && !val.empty? }
        required(:to) { |val| val.is_a?(Integer) && val >= 1 }
        optional(:brokers) { |val| val.nil? || val.is_a?(Hash) }

        # Validate that target replication factor is higher than current
        virtual do |data, errors|
          next unless errors.empty?
          next unless data.key?(:current_rf)

          target_rf = data.fetch(:to)
          current_rf = data.fetch(:current_rf)

          next if target_rf > current_rf

          [[%w[to], :must_be_higher_than_current]]
        end

        # Validate that target replication factor doesn't exceed available brokers
        virtual do |data, errors|
          next unless errors.empty?
          next unless data.key?(:broker_count)

          target_rf = data.fetch(:to)
          broker_count = data.fetch(:broker_count)

          next if target_rf <= broker_count

          [[%w[to], :exceeds_broker_count]]
        end

        # Validate all partitions are specified in manual broker assignment
        virtual do |data, errors|
          next unless errors.empty?

          brokers = data[:brokers]
          next if brokers.nil?
          next unless data.key?(:topic_info)

          topic_info = data.fetch(:topic_info)
          partition_ids = topic_info.fetch(:partitions, []).map { |p| p[:partition_id] }

          missing_partitions = partition_ids - brokers.keys
          next unless missing_partitions.any?

          [[%w[brokers], :missing_partitions]]
        end

        # Validate that manual broker assignments reference valid partitions
        virtual do |data, errors|
          next unless errors.empty?

          brokers = data[:brokers]
          next if brokers.nil?
          next unless data.key?(:topic_info)

          topic_info = data.fetch(:topic_info)
          partition_ids = topic_info.fetch(:partitions, []).map { |p| p[:partition_id] }

          error_found = nil
          brokers.each_key do |partition_id|
            unless partition_ids.include?(partition_id)
              error_found = [[%w[brokers], :invalid_partition]]
              break
            end
          end

          error_found
        end

        # Validate broker count matches target replication factor for each partition
        virtual do |data, errors|
          next unless errors.empty?

          brokers = data[:brokers]
          next if brokers.nil?
          next unless data.key?(:topic_info)

          target_rf = data.fetch(:to)

          error_found = nil
          brokers.each_value do |broker_ids|
            if broker_ids.size != target_rf
              error_found = [[%w[brokers], :wrong_broker_count_for_partition]]
              break
            end
          end

          error_found
        end

        # Validate no duplicate brokers assigned to the same partition
        virtual do |data, errors|
          next unless errors.empty?

          brokers = data[:brokers]
          next if brokers.nil?
          next unless data.key?(:topic_info)

          error_found = nil
          brokers.each_value do |broker_ids|
            if broker_ids.size != broker_ids.uniq.size
              error_found = [[%w[brokers], :duplicate_brokers_for_partition]]
              break
            end
          end

          error_found
        end

        # Validate all referenced brokers exist in the cluster
        virtual do |data, errors|
          next unless errors.empty?

          brokers = data[:brokers]
          next if brokers.nil?
          next unless data.key?(:topic_info)

          cluster_info = data.fetch(:cluster_info, {})
          all_broker_ids = cluster_info.fetch(:brokers, []).map { |b| b[:node_id] }

          error_found = nil
          brokers.each_value do |broker_ids|
            invalid_brokers = broker_ids - all_broker_ids
            if invalid_brokers.any?
              error_found = [[%w[brokers], :invalid_brokers_for_partition]]
              break
            end
          end

          error_found
        end
      end
    end
  end
end
