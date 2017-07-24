# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli
    # Description of topics flow (incoming/outgoing)
    class Flow < Base
      desc 'Print application data flow (incoming => outgoing)'

      # Print out all defined routes in alphabetical order
      def call
        consumers.each do |consumer|
          consumer.topics.each do |topic|
            any_topics = !topic.responder&.topics.nil?

            if any_topics
              puts "#{topic.name} =>"

              topic.responder.topics.each do |_name, topic|
                features = []
                features << (topic.required? ? 'always' : 'conditionally')
                features << (topic.multiple_usage? ? 'one or more' : 'exactly once')

                print topic.name, "(#{features.join(', ')})"
              end
            else
              puts "#{topic.name} => (nothing)"
            end
          end
        end
      end

      private

      # @return [Array<Karafka::Routing::Route>] all routes sorted in alphabetical order
      def consumers
        Karafka::App.consumers.sort_by(&:id)
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
