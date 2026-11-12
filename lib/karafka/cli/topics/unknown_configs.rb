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
        # @param as_new [Boolean] checks every topic as one to be created, also an existing one.
        #   Synonyms are then not accepted, as creating a topic rejects them.
        def initialize(declaratives_topics, existing_topics_names, as_new: false)
          @declaratives_topics = declaratives_topics
          @existing_topics_names = existing_topics_names
          @as_new = as_new
        end

        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] declarative
        #   topics with their configs (names with values) that the cluster does not know. Names
        #   and values are strings, as the cluster returns them.
        # @note Config names are read from an existing topic. When there is no topic we can
        #   describe, the cluster validates the creation of the topics instead. Nothing is
        #   reported for a topic we are not allowed to create either.
        def call
          topics = @declaratives_topics.reject { |topic| topic.declaratives.details.empty? }

          return {} if topics.empty?

          topics_configs = find_topics_configs(topics)

          return find_unknown_on_create(topics) unless topics_configs

          topics.each_with_object({}) do |topic, unknown|
            names = if !@as_new && @existing_topics_names.include?(topic.name)
              topics_configs.names_with_synonyms
            else
              topics_configs.names
            end

            configs = configs(topic).except(*names)

            unknown[topic] = configs unless configs.empty?
          end
        end

        private

        # @param topic [Karafka::Declaratives::Topic] declarative topic
        # @return [Hash{String => String}] topic configs names with values
        def configs(topic)
          topic.declaratives.details.to_h { |name, value| [name.to_s, value.to_s] }
        end

        # @param topics [Array<Karafka::Declaratives::Topic>] declarative topics with configs,
        #   none of which exists, as otherwise we would describe it
        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] declarative
        #   topics with their configs that the cluster does not know. Topics we are not allowed
        #   to create are skipped.
        def find_unknown_on_create(topics)
          Admin.with_admin do |admin|
            new_topics_configs = Cluster::NewTopicsConfigs.new(admin)

            topics.each_with_object({}) do |topic, unknown|
              configs = configs(topic)
              names = new_topics_configs.unknown(topic, configs)

              unknown[topic] = configs.slice(*names) unless names.empty?
            # We may be allowed to create only some of the topics
            rescue Rdkafka::RdkafkaError => e
              raise unless e.code == :topic_authorization_failed
            end
          end
        end

        # @param topics [Array<Karafka::Declaratives::Topic>] declarative topics with configs
        # @return [Cluster::TopicsConfigs, nil] configs of one of our existing topics, otherwise
        #   of any other existing topic. `nil` when there is no topic we can describe.
        def find_topics_configs(topics)
          own = (topics.map(&:name) & @existing_topics_names).first

          return Cluster::TopicsConfigs.new(own) if own

          other = @existing_topics_names.first

          return nil unless other

          topics_configs = Cluster::TopicsConfigs.new(other)
          # Read it here, as we may not be allowed to describe a topic that is not ours
          topics_configs.names
          topics_configs
        rescue Rdkafka::RdkafkaError => e
          raise unless e.code == :topic_authorization_failed

          nil
        end
      end
    end
  end
end
