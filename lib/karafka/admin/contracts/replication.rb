# frozen_string_literal: true

module Karafka
  class Admin
    module Contracts
      # Contract for replication plan parameters
      class Replication < Karafka::Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load(
            File.read(
              File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
            )
          ).fetch('en').fetch('validations').fetch('admin').fetch('replication')
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

        # Validate manual broker assignments when provided
        virtual do |data, errors|
          next unless errors.empty?

          brokers = data[:brokers]
          next if brokers.nil?
          next unless data.key?(:topic_info)

          topic_info = data.fetch(:topic_info)
          target_rf = data.fetch(:to)
          cluster_info = data.fetch(:cluster_info, {})

          partition_ids = topic_info.fetch(:partitions, []).map { |p| p[:partition_id] }
          all_broker_ids = cluster_info.fetch(:brokers, []).map { |b| b[:node_id] }

          # Check all partitions are specified
          missing_partitions = partition_ids - brokers.keys
          if missing_partitions.any?
            [[%w[brokers], :missing_partitions]]
          else
            # Check each partition assignment
            error_found = nil
            brokers.each do |partition_id, broker_ids|
              # Verify partition exists
              unless partition_ids.include?(partition_id)
                error_found = [[%w[brokers], :invalid_partition]]
                break
              end

              # Check broker count matches target RF
              if broker_ids.size != target_rf
                error_found = [[%w[brokers], :wrong_broker_count_for_partition]]
                break
              end

              # Check for duplicate brokers
              if broker_ids.size != broker_ids.uniq.size
                error_found = [[%w[brokers], :duplicate_brokers_for_partition]]
                break
              end

              # Check all brokers exist
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
end