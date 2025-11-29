# frozen_string_literal: true

module Karafka
  class Admin
    # Replication administration operations helper
    #
    # Generates partition reassignment plans for increasing topic replication factor.
    # Since librdkafka does not support changing replication factors directly, this class
    # generates the necessary JSON configuration that can be executed using Kafka's Java-based
    # reassignment tools.
    #
    # ## Important Considerations
    #
    # Replication factor changes are among the most resource-intensive operations in Kafka.
    #
    # ## Prerequisites
    #
    # 1. **Sufficient Disk Space**: Ensure target brokers have enough space for new replicas
    # 2. **Network Capacity**: Verify network can handle additional replication traffic
    # 3. **Broker Count**: Cannot exceed the number of available brokers
    # 4. **Java Tools**: Kafka's reassignment tools must be available
    #
    # ## Best Practices
    #
    # - **Test First**: Always test on small topics or in staging environments
    # - **Monitor Resources**: Watch disk space, network, and CPU during replication
    # - **Incremental Changes**: Increase replication factor by 1 at a time for large topics
    # - **Off-Peak Hours**: Execute during low-traffic periods to minimize impact
    #
    # @example Basic usage - increase replication factor
    #   # Generate plan to increase replication from 2 to 3
    #   plan = Karafka::Admin::Replication.plan(topic: 'events', to: 3)
    #
    #   # Review what will happen
    #   puts plan.summary
    #
    #   # Export for execution
    #   plan.export_to_file('/tmp/increase_replication.json')
    #
    #   # Execute with Kafka tools (outside of Ruby)
    #   # kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
    #   #   --reassignment-json-file /tmp/increase_replication.json --execute
    #
    # @example Rebalancing replicas across brokers
    #   # Rebalance existing replicas without changing replication factor
    #   plan = Karafka::Admin::Replication.rebalance(topic: 'events')
    #   plan.export_to_file('/tmp/rebalance.json')
    #
    # @note This class only generates plans - actual execution requires Kafka's Java tools
    # @note Always verify broker capacity before increasing replication
    class Replication < Admin
      attr_reader(
        :topic,
        :current_replication_factor,
        :target_replication_factor,
        :partitions_assignment,
        :reassignment_json,
        :execution_commands,
        :steps
      )

      # Builds the replication plan
      #
      # @param topic [String] topic name
      # @param current_replication_factor [Integer] current replication factor
      # @param target_replication_factor [Integer] target replication factor
      # @param partitions_assignment [Hash] partition to brokers assignment
      # @param cluster_info [Hash] broker information
      def initialize(
        topic:,
        current_replication_factor:,
        target_replication_factor:,
        partitions_assignment:,
        cluster_info:
      )
        super()

        @topic = topic
        @current_replication_factor = current_replication_factor
        @target_replication_factor = target_replication_factor
        @partitions_assignment = partitions_assignment
        @cluster_info = cluster_info

        generate_reassignment_json
        generate_execution_commands
        generate_steps

        freeze
      end

      # Export the reassignment JSON to a file
      # @param file_path [String] path where to save the JSON file
      def export_to_file(file_path)
        File.write(file_path, @reassignment_json)
        file_path
      end

      # @return [String] human-readable summary of the plan
      def summary
        broker_count = @cluster_info[:brokers].size
        change = @target_replication_factor - @current_replication_factor
        broker_nodes = @cluster_info[:brokers].map do |broker_info|
          broker_info[:node_id]
        end.join(', ')

        <<~SUMMARY
          Replication Increase Plan for Topic: #{@topic}
          =====================================
          Current replication factor: #{@current_replication_factor}
          Target replication factor: #{@target_replication_factor}
          Total partitions: #{@partitions_assignment.size}
          Available brokers: #{broker_count} (#{broker_nodes})

          This plan will increase replication by adding #{change} replica(s) to each partition.
        SUMMARY
      end

      class << self
        # Plans replication factor increase for a given topic
        #
        # Generates a detailed reassignment plan that preserves existing replica assignments
        # while adding new replicas to meet the target replication factor. The plan uses
        # round-robin distribution to balance new replicas across available brokers.
        #
        # @param topic [String] name of the topic
        # @param to [Integer] target replication factor (must be higher than current)
        # @param brokers [Hash{Integer => Array<Integer>}] optional manual broker assignments
        #   per partition. Keys are partition IDs, values are arrays of broker IDs. If not provided
        #   automatic distribution (usually fine) will be used
        # @return [Replication] plan object containing JSON, commands, and instructions
        #
        # @raise [ArgumentError] if target replication factor is not higher than current
        # @raise [ArgumentError] if target replication factor exceeds available broker count
        # @raise [Rdkafka::RdkafkaError] if topic metadata cannot be fetched
        #
        # @example Increase replication from 1 to 3 with automatic distribution
        #   plan = Replication.plan(topic: 'events', to: 3)
        #
        #   # Inspect the plan
        #   puts plan.summary
        #   puts plan.reassignment_json
        #
        #   # Check which brokers will get new replicas
        #   plan.partitions_assignment.each do |partition_id, broker_ids|
        #     puts "Partition #{partition_id}: #{broker_ids.join(', ')}"
        #   end
        #
        #   # Save and execute
        #   plan.export_to_file('increase_rf.json')
        #
        # @example Increase replication with manual broker placement
        #   # Specify exactly which brokers should host each partition
        #   plan = Replication.plan(
        #     topic: 'events',
        #     to: 3,
        #     brokers: {
        #       0 => [1, 2, 4],  # Partition 0 on brokers 1, 2, 4
        #       1 => [2, 3, 4],  # Partition 1 on brokers 2, 3, 4
        #       2 => [1, 3, 5]   # Partition 2 on brokers 1, 3, 5
        #     }
        #   )
        #
        #   # The plan will use your exact broker specifications
        #   puts plan.partitions_assignment
        #   # => {0=>[1, 2, 4], 1=>[2, 3, 4], 2=>[1, 3, 5]}
        #
        # @note When using manual placement, ensure all partitions are specified
        # @note Manual placement overrides automatic distribution entirely
        def plan(topic:, to:, brokers: nil)
          topic_info = fetch_topic_info(topic)
          first_partition = topic_info[:partitions].first
          current_rf = first_partition[:replica_count] || first_partition[:replicas]&.size
          cluster_info = fetch_cluster_info

          # Use contract for validation
          validation_data = {
            topic: topic,
            to: to,
            brokers: brokers,
            current_rf: current_rf,
            broker_count: cluster_info[:brokers].size,
            topic_info: topic_info,
            cluster_info: cluster_info
          }

          Contracts::Replication.new.validate!(validation_data)

          partitions_assignment = brokers || generate_partitions_assignment(
            topic_info: topic_info,
            target_replication_factor: to,
            cluster_info: cluster_info
          )

          new(
            topic: topic,
            current_replication_factor: current_rf,
            target_replication_factor: to,
            partitions_assignment: partitions_assignment,
            cluster_info: cluster_info
          )
        end

        # Plans rebalancing of existing replicas across brokers
        #
        # Generates a reassignment plan that redistributes existing replicas more evenly
        # across the cluster without changing the replication factor. Useful for:
        #
        # - Balancing load after adding new brokers to the cluster
        # - Redistributing replicas after broker failures and recovery
        # - Optimizing replica placement for better resource utilization
        # - Moving replicas away from overloaded brokers
        #
        # @param topic [String] name of the topic to rebalance
        # @return [Replication] rebalancing plan
        #
        # @example Rebalance after adding new brokers
        #   # After adding brokers 4 and 5 to a 3-broker cluster
        #   plan = Replication.rebalance(topic: 'events')
        #
        #   # Review how replicas will be redistributed
        #   puts plan.summary
        #
        #   # Execute if distribution looks good
        #   plan.export_to_file('rebalance.json')
        #   # Then run: kafka-reassign-partitions.sh --execute ...
        #
        # @note This maintains the same replication factor
        # @note All data will be copied to new locations during rebalancing
        # @note Consider impact on cluster resources during rebalancing
        def rebalance(topic:)
          topic_info = fetch_topic_info(topic)
          first_partition = topic_info[:partitions].first
          current_rf = first_partition[:replica_count] || first_partition[:replicas]&.size
          cluster_info = fetch_cluster_info

          partitions_assignment = generate_partitions_assignment(
            topic_info: topic_info,
            target_replication_factor: current_rf,
            cluster_info: cluster_info,
            rebalance_only: true
          )

          new(
            topic: topic,
            current_replication_factor: current_rf,
            target_replication_factor: current_rf,
            partitions_assignment: partitions_assignment,
            cluster_info: cluster_info
          )
        end

        private

        # Fetches topic metadata including partitions and replica information
        # @param topic [String] name of the topic
        # @return [Hash] topic information with partitions metadata
        def fetch_topic_info(topic)
          Topics.info(topic)
        end

        # Fetches cluster broker information from Kafka metadata
        # @return [Hash] cluster information with broker details (node_id, host:port)
        def fetch_cluster_info
          cluster_metadata = cluster_info
          {
            brokers: cluster_metadata.brokers.map do |broker|
              # Handle both hash and object formats from metadata
              # rdkafka returns hashes with broker_id, broker_name, broker_port
              if broker.is_a?(Hash)
                node_id = broker[:broker_id] || broker[:node_id]
                host = broker[:broker_name] || broker[:host]
                port = broker[:broker_port] || broker[:port]
                { node_id: node_id, host: "#{host}:#{port}" }
              else
                { node_id: broker.node_id, host: "#{broker.host}:#{broker.port}" }
              end
            end
          }
        end

        # Generates partition-to-broker assignments for replication changes
        # Handles both replication factor increases and rebalancing scenarios
        # @param topic_info [Hash] topic metadata with partition information
        # @param target_replication_factor [Integer] desired replication factor
        # @param cluster_info [Hash] cluster metadata with broker information
        # @param rebalance_only [Boolean] true for rebalancing, false for increase
        # @return [Hash{Integer => Array<Integer>}] assignments (partition_id => broker_ids)
        def generate_partitions_assignment(
          topic_info:,
          target_replication_factor:,
          cluster_info:,
          rebalance_only: false
        )
          partitions = topic_info[:partitions]
          brokers = cluster_info[:brokers].map { |broker_info| broker_info[:node_id] }.sort
          assignments = {}

          partitions.each do |partition_info|
            partition_id = partition_info[:partition_id]

            # Handle both :replicas (array of objects) and :replica_brokers (array of IDs)
            replicas = partition_info[:replicas] || partition_info[:replica_brokers] || []
            current_replicas = if replicas.first.respond_to?(:node_id)
                                 replicas.map(&:node_id).sort
                               else
                                 replicas.sort
                               end

            if rebalance_only
              # For rebalancing, redistribute current replicas optimally
              new_replicas = select_brokers_for_partition(
                partition_id: partition_id,
                brokers: brokers,
                replica_count: target_replication_factor,
                avoid_brokers: []
              )
            else
              # For replication increase, keep existing replicas and add new ones
              additional_needed = target_replication_factor - current_replicas.size
              available_brokers = brokers - current_replicas

              additional_replicas = select_additional_brokers(
                available_brokers: available_brokers,
                needed_count: additional_needed,
                partition_id: partition_id
              )

              new_replicas = (current_replicas + additional_replicas).sort
            end

            assignments[partition_id] = new_replicas
          end

          assignments
        end

        # Selects brokers for a partition using round-robin distribution
        # Distributes replicas evenly across available brokers
        # @param partition_id [Integer] partition identifier for offset calculation
        # @param brokers [Array<Integer>] available broker node IDs
        # @param replica_count [Integer] number of replicas needed
        # @param avoid_brokers [Array<Integer>] broker IDs to exclude from selection
        # @return [Array<Integer>] sorted array of selected broker node IDs
        def select_brokers_for_partition(
          partition_id:,
          brokers:,
          replica_count:,
          avoid_brokers: []
        )
          available_brokers = brokers - avoid_brokers

          # Simple round-robin selection starting from a different offset per partition
          # This helps distribute replicas more evenly across brokers
          start_index = partition_id % available_brokers.size
          selected = []

          replica_count.times do |replica_index|
            broker_index = (start_index + replica_index) % available_brokers.size
            selected << available_brokers[broker_index]
          end

          selected.sort
        end

        # Selects additional brokers for increasing replication factor
        # Uses round-robin selection for even distribution across available brokers
        # @param available_brokers [Array<Integer>] broker IDs available for new replicas
        # @param needed_count [Integer] number of additional brokers needed
        # @param partition_id [Integer] partition identifier for offset calculation
        # @return [Array<Integer>] sorted array of selected broker node IDs
        def select_additional_brokers(available_brokers:, needed_count:, partition_id:)
          # Use round-robin starting from partition-specific offset
          start_index = partition_id % available_brokers.size
          selected = []

          needed_count.times do |additional_replica_index|
            broker_index = (start_index + additional_replica_index) % available_brokers.size
            selected << available_brokers[broker_index]
          end

          selected.sort
        end
      end

      private

      # Generates the JSON structure required by kafka-reassign-partitions.sh
      # Creates Kafka-compatible reassignment plan with version and partitions data
      # @return [void]
      def generate_reassignment_json
        partitions_data = @partitions_assignment.map do |partition_id, replica_broker_ids|
          {
            topic: @topic,
            partition: partition_id,
            replicas: replica_broker_ids
          }
        end

        reassignment_data = {
          version: 1,
          partitions: partitions_data
        }

        @reassignment_json = JSON.pretty_generate(reassignment_data)
      end

      # Generates command templates for executing the reassignment plan
      # Builds generate, execute, and verify command templates with placeholders
      # @return [void]
      def generate_execution_commands
        @execution_commands = {
          generate: build_generate_command,
          execute: build_execute_command,
          verify: build_verify_command
        }
      end

      # Builds the kafka-reassign-partitions.sh command for generating reassignment plan
      # @return [String] command template with placeholder for broker addresses
      def build_generate_command
        'kafka-reassign-partitions.sh --bootstrap-server <KAFKA_BROKERS> ' \
          '--reassignment-json-file reassignment.json --generate'
      end

      # Builds the kafka-reassign-partitions.sh command for executing reassignment
      # @return [String] command template with placeholder for broker addresses
      def build_execute_command
        'kafka-reassign-partitions.sh --bootstrap-server <KAFKA_BROKERS> ' \
          '--reassignment-json-file reassignment.json --execute'
      end

      # Builds the kafka-reassign-partitions.sh command for verifying reassignment progress
      # @return [String] command template with placeholder for broker addresses
      def build_verify_command
        'kafka-reassign-partitions.sh --bootstrap-server <KAFKA_BROKERS> ' \
          '--reassignment-json-file reassignment.json --verify'
      end

      # Generates detailed step-by-step instructions for executing the reassignment
      # Creates human-readable guide with commands and important safety notes
      # @return [void]
      def generate_steps
        @steps = [
          "1. Export the reassignment JSON using: plan.export_to_file('reassignment.json')",
          "2. Validate the plan (optional): #{@execution_commands[:generate]}",
          "3. Execute the reassignment: #{@execution_commands[:execute]}",
          "4. Monitor progress: #{@execution_commands[:verify]}",
          '5. Verify completion by checking topic metadata',
          '',
          'IMPORTANT NOTES:',
          '- Replace <KAFKA_BROKERS> with your actual Kafka broker addresses',
          '- The reassignment process may take time depending on data size',
          '- Monitor disk space and network I/O during reassignment',
          '- Consider running during low-traffic periods',
          '- For large topics, consider throttling replica transfer rate',
          '- Ensure sufficient disk space on target brokers before starting',
          '- Keep monitoring until all replicas are in-sync (ISR)'
        ]
      end
    end
  end
end
