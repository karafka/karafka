# frozen_string_literal: true

module Karafka
  module Routing
    module Contracts
      # Ensures that routing wide rules are obeyed
      class Routing < Karafka::Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("routing")
        end

        # Ensures, that when declarative topics strict requirement is on, all topics have
        # declarative definition (including DLQ topics). It will ignore routing pattern topics
        # because those topics are virtual
        virtual do |data, errors|
          next unless errors.empty?
          # Do not validate declaratives unless required and explicitly enabled
          next unless Karafka::App.config.strict_declarative_topics

          # Declarative topic definitions live independently of routing (in the declaratives
          # repository, populated via `Karafka::App.declaratives.draw`). A routed topic is
          # considered declaratively managed when it has an active declaration there.
          declaratives = Karafka::App.declaratives
          # All topics including the DLQ topics names that are marked as active
          topics = Set.new

          data.each do |group|
            group[:topics].each do |topic|
              pat = topic[:patterns]
              # Ignore pattern topics because they won't exist and should not be declarative managed
              topics << topic[:name] if !pat || !pat[:active]

              dlq = topic[:dead_letter_queue]
              topics << dlq[:topic] if dlq[:active]
            end
          end

          missing_dec = topics.reject do |topic_name|
            declaration = declaratives.find_topic(topic_name)
            declaration && declaration.active?
          end

          next if missing_dec.empty?

          missing_dec.map do |topic_name|
            [
              [:topics, topic_name],
              :without_declarative_definition
            ]
          end
        end
      end
    end
  end
end
