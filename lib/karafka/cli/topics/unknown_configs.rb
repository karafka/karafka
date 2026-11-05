# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Finds configuration of existing declarative topics that the cluster does not know.
      # Such configuration (e.g. a typo in a config name) could never be applied.
      class UnknownConfigs
        # @param declaratives_topics [Array<Karafka::Declaratives::Topic>] declarative topics
        # @param existing_topics_names [Array<String>] names of topics that exist in the cluster
        def initialize(declaratives_topics, existing_topics_names)
          @declaratives_topics = declaratives_topics
          @existing_topics_names = existing_topics_names
        end

        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] existing
        #   declarative topics with their configs (names with values) that the cluster does not
        #   know. Names and values are strings, as the cluster returns them.
        def call
          topics = @declaratives_topics.select do |topic|
            !topic.declaratives.details.empty? && @existing_topics_names.include?(topic.name)
          end

          return {} if topics.empty?

          names = Cluster::TopicsConfigs.new(topics.first.name).names

          topics.each_with_object({}) do |topic, unknown|
            configs = topic
              .declaratives
              .details
              .to_h { |name, value| [name.to_s, value.to_s] }
              .except(*names)

            unknown[topic] = configs unless configs.empty?
          end
        end
      end
    end
  end
end
