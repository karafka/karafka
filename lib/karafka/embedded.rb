# frozen_string_literal: true

module Karafka
  # Allows to start and stop Karafka as part of a different process
  # Following limitations and restrictions apply:
  #
  # - `#start` cannot be called from a trap context - non blocking
  # - `#quiet` - can be called from a trap context - non blocking
  # - `#stop` - can be called from a trap context - blocking
  module Embedded
    class << self
      # Lock for ensuring we do not control embedding in parallel
      MUTEX = Mutex.new

      private_constant :MUTEX

      # Starts Karafka without supervision and without ownership of signals in a background thread
      # so it won't interrupt other things running
      def start
        MUTEX.synchronize do
          # Prevent from double-starting
          return if @started

          @started = true
        end

        Thread.new do
          Thread.current.name = 'karafka.embedded'

          Karafka::Process.tags.add(:execution_mode, 'mode:embedded')
          Karafka::Server.execution_mode = :embedded
          Karafka::Server.start
        end
      end

      # Stops Karafka upon any event
      #
      # @note This method is blocking because we want to wait until Karafka is stopped with final
      #   process shutdown
      #
      # @note This method **is** safe to run from a trap context.
      def stop
        # Prevent from double stopping
        unless @stopping
          Thread.new do
            Thread.current.name = 'karafka.embedded.stopping'

            stop = false

            # We spawn a new thread because `#stop` may be called from a trap context
            MUTEX.synchronize do
              break if @stopping

              @stopping = true
              stop = true
            end

            next unless stop

            Karafka::Server.stop
          end
        end

        # Since we want to have this blocking, we wait for the background thread
        sleep(0.1) until Karafka::App.terminated?
      end

      # Quiets Karafka upon any event
      #
      # @note This method is not blocking and will not wait for Karafka to fully quiet.
      # It will trigger the quiet procedure but won't wait.
      #
      # @note This method **can** be called from a trap context.
      #
      # @note Please keep in mind you need to `#stop` to actually stop the server anyhow.
      def quiet
        Karafka::Server.quiet
      end
    end
  end
end
