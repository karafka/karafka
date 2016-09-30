module Karafka
  # Karafka framework Cli
  class Cli
    # Description of topics flow (incoming/outgoing)
    class Flow < Base
      desc 'Print application data flow (incoming => outgoing)'

      # Print out all defined routes in alphabetical order
      def call
        routes.each do |route|
          any_topics = !route.responder&.topics.nil?

          if any_topics
            puts "#{route.topic} =>"

            route.responder.topics.each do |_name, topic|
              features = []
              features << (topic.required? ? 'always' : 'conditionally')
              features << (topic.multiple_usage? ? 'one or more' : 'exactly once')

              print topic.name, "(#{features.join(', ')})"
            end
          else
            puts "#{route.topic} => (nothing)"
          end
        end
      end

      private

      # @return [Array<Karafka::Routing::Route>] all routes sorted in alphabetical order
      def routes
        Karafka::App.routes.sort do |route1, route2|
          route1.topic <=> route2.topic
        end
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
