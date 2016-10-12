module Karafka
  # Karafka framework Cli
  class Cli
    # Routes Karafka Cli action
    class Routes < Base
      desc 'Print out all defined routes in alphabetical order'
      option aliases: 'r'

      # Print out all defined routes in alphabetical order
      def call
        routes.each do |route|
          puts "#{route.topic}:"
          Karafka::Routing::Route::ATTRIBUTES.each do |attr|
            print(attr.to_s.capitalize, route.public_send(attr))
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
        printf "%-18s %s\n", "  - #{label}:", value
      end
    end
  end
end
