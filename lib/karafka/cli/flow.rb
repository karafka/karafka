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

          if any_topics
            puts "#{topic.name} =>"

            topic.responder.topics.each_value do |responder_topic|
              features = []
              features << (responder_topic.required? ? 'always' : 'conditionally')
              features << (responder_topic.multiple_usage? ? 'one or more' : 'exactly once')

              print responder_topic.name, "(#{features.join(', ')})"
            end
          else
            puts "#{topic.name} => (nothing)"
          end
        end
      end

      private

      # @return [Array<Karafka::Routing::Topic>] all topics sorted in alphabetical order
      def topics
        Karafka::App.consumer_groups.map(&:topics).flatten.sort_by(&:name)
      end

      # Prints a given value with label in a nice way
      # @param label [String] label describing value
      # @param value [String] value that should be printed
      def print(label, value)
        printf "%-25s %s\n", "  - #{label}:", value
      end
    end
  end
end
