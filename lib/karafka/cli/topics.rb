# frozen_string_literal: true

module Karafka
  class Cli < Thor
    # CLI actions related to Kafka cluster topics management
    class Topics < Base
      include Helpers::Colorize

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
        else
          raise ::ArgumentError, "Invalid topics action: #{action}"
        end
      end

      private

      # Creates topics based on the routing setup and configuration
      def create
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
          end
        end
      end

      # Deletes routing based topics
      def delete
        declaratives_routing_topics.each do |topic|
          name = topic.name

          if existing_topics_names.include?(name)
            puts "Deleting topic #{name}..."
            Admin.delete_topic(name)
            puts "#{green('Deleted')} topic #{name}."
          else
            puts "#{yellow('Skipping')} because topic #{name} does not exist."
          end
        end
      end

      # Deletes routing based topics and re-creates them
      def reset
        delete

        # We need to invalidate the metadata cache, otherwise we will think, that the topic
        # already exists
        @existing_topics = nil

        create
      end

      # Creates missing topics and aligns the partitions count
      def migrate
        create

        @existing_topics = nil

        repartition
      end

      # Increases number of partitions on topics that have less partitions than defined
      # Will **not** create topics if missing.
      def repartition
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
          elsif existing_count
            puts "#{yellow('Skipping')} because topic #{name} has #{existing_count} partitions."
          else
            puts "#{yellow('Skipping')} because topic #{name} does not exist."
          end
        end
      end

      # @return [Array<Karafka::Routing::Topic>] all available topics that can be managed
      # @note If topic is defined in multiple consumer groups, first config will be used. This
      #   means, that this CLI will not work for simultaneous management of multiple clusters from
      #   a single CLI command execution flow.
      def declaratives_routing_topics
        return @declaratives_routing_topics if @declaratives_routing_topics

        collected_topics = {}
        default_servers = Karafka::App.config.kafka[:'bootstrap.servers']

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
    end
  end
end
