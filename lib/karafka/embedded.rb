# frozen_string_literal: true

module Karafka
  # Allows to start and stop Karafka as part of a different process
  module Embedded
    class << self
      # Starts Karafka without supervision and without ownership of signals in a background thread
      # so it won't interrupt other things running
      def start
        Thread.new { Karafka::Server.start }
      end

      # Stops Karafka upon any event
      #
      # @note This method is blocking because we want to wait until Karafka is stopped with final
      #   process shutdown
      def stop
        # Stop needs to be blocking to wait for all the things to finalize
        Karafka::Server.stop
      end
    end
  end
end
