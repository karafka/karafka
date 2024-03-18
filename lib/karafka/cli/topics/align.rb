# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
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
      class Align < Base
        # @return [Boolean] true if there were any changes applied, otherwise false
        def call
          if candidate_topics.empty?
            puts "#{yellow('Skipping')} because no declarative topics exist."

            return false
          end

          resources_to_migrate = build_resources_to_migrate

          if resources_to_migrate.empty?
            puts "#{yellow('Skipping')} because there are no configurations to align."

            return false
          end

          names = resources_to_migrate.map(&:name).join(', ')
          puts "Updating configuration of the following topics: #{names}"
          Karafka::Admin::Configs.alter(resources_to_migrate)
          puts "#{green('Updated')} all requested topics configuration."

          true
        end

        private

        # Selects topics that exist and potentially may have config to align
        #
        # @return [Set<Karafka::Routing::Topic>]
        def candidate_topics
          return @candidate_topics if @candidate_topics

          @candidate_topics = Set.new

          # First lets only operate on topics that do exist
          declaratives_routing_topics.each do |topic|
            unless existing_topics_names.include?(topic.name)
              puts "#{yellow('Skipping')} because topic #{topic.name} does not exist."
              next
            end

            @candidate_topics << topic
          end

          @candidate_topics
        end

        # Iterates over configs of all the candidate topics and prepares alignment resources for
        # a single request to Kafka
        # @return [Array<Karafka::Admin::Configs::Resource>] all topics with config change requests
        def build_resources_to_migrate
          # We build non-fetched topics resources representations for further altering
          resources = candidate_topics.map do |topic|
            Admin::Configs::Resource.new(type: :topic, name: topic.name)
          end

          resources_to_migrate = Set.new

          # We fetch all the configurations for all the topics
          Admin::Configs.describe(resources).each do |topic_with_configs|
            t_candidate = candidate_topics.find do |candidate|
              candidate.name == topic_with_configs.name
            end

            change_resource = resources.find do |resource|
              resource.name == topic_with_configs.name
            end

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

          resources_to_migrate.to_a
        end
      end
    end
  end
end
