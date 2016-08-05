module Karafka
  class Cli
    # Consuming action without a loop
    class Consume < Base
      self.desc = 'Start messages consuming'

      # Start the Karafka server
      def call
        puts 'Starting Karafka messages consuming process'

        Karafka::Consumer.run
      end
    end
  end
end
