# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Description of topics flow (incoming/outgoing)
    class Flow < Base
      desc 'Print application data flow (incoming => outgoing)'

      # Print out all defined routes in alphabetical order
      def call
        topics.each do |topic|
          any_topics = !topic.responder&.topics.nil?
          log_messages = []

          if any_topics
            log_messages << "#{topic.name} =>"

            topic.responder.topics.each_value do |responder_topic|
              features = []
              features << (responder_topic.required? ? 'always' : 'conditionally')

              log_messages << format(responder_topic.name, "(#{features.join(', ')})")
            end
          else
            log_messages << "#{topic.name} => (nothing)"
          end

          Karafka.logger.info(log_messages.join("\n"))
        end
      end

      private

      # @return [Array<Karafka::Routing::Topic>] all topics sorted in alphabetical order
      def topics
        Karafka::App.consumer_groups.map(&:topics).flatten.sort_by(&:name)
      end

      # Formats a given value with label in a nice way
      # @param label [String] label describing value
      # @param value [String] value that should be printed
      def format(label, value)
        "  - #{label}:                #{value}"
      end
    end
  end
end
