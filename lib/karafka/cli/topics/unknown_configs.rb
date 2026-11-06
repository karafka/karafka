# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Finds configuration of declarative topics that the cluster does not know.
      # Such configuration (e.g. a typo in a config name) could never be applied, neither when
      # creating a topic nor when altering an existing one.
      class UnknownConfigs
        # @param declaratives_topics [Array<Karafka::Declaratives::Topic>] declarative topics
        # @param existing_topics_names [Array<String>] names of topics that exist in the cluster
        def initialize(declaratives_topics, existing_topics_names)
          @declaratives_topics = declaratives_topics
          @existing_topics_names = existing_topics_names
        end

        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] declarative
        #   topics with their configs (names with values) that the cluster does not know. Names
        #   and values are strings, as the cluster returns them.
        # @note Config names are read from an existing topic, so nothing is reported when the
        #   cluster has no topics at all.
        def call
          topics = @declaratives_topics.reject { |topic| topic.declaratives.details.empty? }

          return {} if topics.empty? || @existing_topics_names.empty?

          # Prefer one of our topics, so we describe a topic we are expected to have access to
          reference = (topics.map(&:name) & @existing_topics_names).first
          reference ||= @existing_topics_names.first

          names = Cluster::TopicsConfigs.new(reference).names

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
