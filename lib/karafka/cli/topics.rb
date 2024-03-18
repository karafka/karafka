# frozen_string_literal: true

module Karafka
  class Cli
    # CLI actions related to Kafka cluster topics management
    class Topics < Base
      include Helpers::Colorize
      include Helpers::ConfigImporter.new(
        kafka_config: %i[kafka]
      )

      desc 'Allows for the topics management (create, delete, reset, repartition)'
      # @param action [String] action we want to take
      def call(action = 'missing')
        case action
        when 'create'
          create
        when 'delete'
          delete
        when 'reset'
          reset
        when 'repartition'
          repartition
        when 'migrate'
          migrate
        when 'align'
          align
        else
          raise ::ArgumentError, "Invalid topics action: #{action}"
        end
      end

      private

      # Creates topics based on the routing setup and configuration
      # @return [Boolean] true if any topic was created, otherwise false
      def create
        any_created = false

        declaratives_routing_topics.each do |topic|
          name = topic.name

          if existing_topics_names.include?(name)
            puts "#{yellow('Skipping')} because topic #{name} already exists."
          else
            puts "Creating topic #{name}..."
            Admin.create_topic(
              name,
              topic.declaratives.partitions,
              topic.declaratives.replication_factor,
              topic.declaratives.details
            )
            puts "#{green('Created')} topic #{name}."
            any_created = true
          end
        end

        any_created
      end

      # Deletes routing based topics
      # @return [Boolean] true if any topic was deleted, otherwise false
      def delete
        any_deleted = false

        declaratives_routing_topics.each do |topic|
          name = topic.name

          if existing_topics_names.include?(name)
            puts "Deleting topic #{name}..."
            Admin.delete_topic(name)
            puts "#{green('Deleted')} topic #{name}."
            any_deleted = true
          else
            puts "#{yellow('Skipping')} because topic #{name} does not exist."
          end
        end

        any_deleted
      end

      # Deletes routing based topics and re-creates them
      def reset
        delete && wait

        # We need to invalidate the metadata cache, otherwise we will think, that the topic
        # already exists
        @existing_topics = nil

        create
      end

      # Creates missing topics and aligns the partitions count
      def migrate
        create && wait

        @existing_topics = nil

        repartition && wait
        align
      end

      # Increases number of partitions on topics that have less partitions than defined
      # Will **not** create topics if missing.
      # @return [Boolean] true if anything was repartitioned, otherwise false
      def repartition
        any_repartitioned = false

        existing_partitions = existing_topics.map do |topic|
          [topic.fetch(:topic_name), topic.fetch(:partition_count)]
        end.to_h

        declaratives_routing_topics.each do |topic|
          name = topic.name

          desired_count = topic.config.partitions
          existing_count = existing_partitions.fetch(name, false)

          if existing_count && existing_count < desired_count
            puts "Increasing number of partitions to #{desired_count} on topic #{name}..."
            Admin.create_partitions(name, desired_count)
            change = desired_count - existing_count
            puts "#{green('Created')} #{change} additional partitions on topic #{name}."
            any_repartitioned = true
          elsif existing_count
            puts "#{yellow('Skipping')} because topic #{name} has #{existing_count} partitions."
          else
            puts "#{yellow('Skipping')} because topic #{name} does not exist."
          end
        end

        any_repartitioned
      end

      # Aligns configuration of all the declarative topics that exist based on the declarative
      # topics definitions.
      #
      # Takes into consideration already existing settings, so will only align what is needed.
      #
      # Keep in mind, this is NOT transactional. Kafka topic changes are not transactional so
      # it is highly recommended to test it before running in prod.
      #
      # @note This command does NOT repartition and does NOT create new topics. It only aligns
      #   configuration of existing topics.
      def align
        candidates = Set.new

        # First lets only operate on topics that do exist
        declaratives_routing_topics.each do |topic|
          unless existing_topics_names.include?(topic.name)
            puts "#{yellow('Skipping')} because topic #{topic.name} does not exist."
            next
          end

          candidates << topic
        end

        # We build non-fetched topics resources representations for further altering
        resources = candidates.map do |topic|
          Admin::Configs::Resource.new(type: :topic, name: topic.name)
        end

        resources_to_migrate = Set.new

        if resources.empty?
          puts "#{yellow('Skipping')} because no declarative topics exist."

          return false
        end

        # We fetch all the configurations for all the topics
        Admin::Configs.describe(resources).each do |topic_with_configs|
          t_candidate = candidates.find { |candidate| candidate.name == topic_with_configs.name }
          change_resource = resources.find { |resource| resource.name == topic_with_configs.name }

          # librdkafka returns us all the results as strings, so we need to align our config
          # representation so we can compare those
          desired_configs = t_candidate.declaratives.details.dup
          desired_configs.transform_values!(&:to_s)
          desired_configs.transform_keys!(&:to_s)

          topic_with_configs.configs.each do |config|
            next unless desired_configs.key?(config.name)

            desired_config = desired_configs.fetch(config.name)

            # Do not migrate if existing and desired values are the same
            next if desired_config == config.value

            change_resource.set(config.name, desired_config)
            resources_to_migrate << change_resource
          end
        end

        if resources_to_migrate.empty?
          puts "#{yellow('Skipping')} because there are no configurations to align."
        else
          names = resources_to_migrate.map(&:name).join(', ')
          puts "Updating configuration of the following topics: #{names}"
          Karafka::Admin::Configs.alter(resources)
          puts "#{green('Updated')} all requested topics configuration."
        end

        !resources_to_migrate.empty?
      end

      # @return [Array<Karafka::Routing::Topic>] all available topics that can be managed
      # @note If topic is defined in multiple consumer groups, first config will be used. This
      #   means, that this CLI will not work for simultaneous management of multiple clusters from
      #   a single CLI command execution flow.
      def declaratives_routing_topics
        return @declaratives_routing_topics if @declaratives_routing_topics

        collected_topics = {}
        default_servers = kafka_config[:'bootstrap.servers']

        App.consumer_groups.each do |consumer_group|
          consumer_group.topics.each do |topic|
            # Skip topics that were explicitly disabled from management
            next unless topic.declaratives.active?
            # If bootstrap servers are different, consider this a different cluster
            next unless default_servers == topic.kafka[:'bootstrap.servers']

            collected_topics[topic.name] ||= topic
          end
        end

        @declaratives_routing_topics = collected_topics.values
      end

      # @return [Array<Hash>] existing topics details
      def existing_topics
        @existing_topics ||= Admin.cluster_info.topics
      end

      # @return [Array<String>] names of already existing topics
      def existing_topics_names
        existing_topics.map { |topic| topic.fetch(:topic_name) }
      end

      # Waits with a message, that we are waiting on topics
      # This is not doing much, just waiting as there are some cases that it takes a bit of time
      # for Kafka to actually propagate new topics knowledge across the cluster. We give it that
      # bit of time just in case.
      def wait
        print 'Waiting for the topics to synchronize in the cluster'

        5.times do
          sleep(1)
          print '.'
        end

        puts
      end
    end
  end
end
