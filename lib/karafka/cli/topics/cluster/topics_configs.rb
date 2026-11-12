# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Cluster level details used by the topics commands
      module Cluster
        # Topic configuration names the cluster knows.
        #
        # All topics of a cluster share the same set of configuration names, so we describe one
        # existing topic and reuse its names for any other topic.
        class TopicsConfigs
          # @param topic_name [String] name of any existing topic
          def initialize(topic_name)
            @topic_name = topic_name
          end

          # @return [Array<String>] names of all topic configs, without their synonyms
          # @note Only those names are accepted when creating a topic
          def names
            @names ||= configs.map(&:name)
          end

          # @return [Array<String>] names of all topic configs with their synonyms
          # @note Synonyms are accepted only when altering an existing topic
          def names_with_synonyms
            @names_with_synonyms ||= configs.flat_map do |config|
              config.synonyms.map(&:name) << config.name
            end
          end

          private

          # @return [Array<Karafka::Admin::Configs::Config>] configs of the described topic
          def configs
            @configs ||= begin
              resource = Admin::Configs::Resource.new(type: :topic, name: @topic_name)

              Admin::Configs.describe(resource).first.configs
            end
          end
        end
      end
    end
  end
end
