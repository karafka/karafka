# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Listener that watches the `error.occurred` bus for process-critical errors and initiates a
    # graceful shutdown when one appears, regardless of where in the framework it surfaced
    # (consumption flow, after-consume flow, worker, etc.).
    #
    # Process-critical errors (see the `internal.processing.critical_errors` setting) are not
    # something a retry can handle: SystemExit means termination was explicitly requested and
    # NoMemoryError means the VM cannot be trusted to continue. The error containment in the
    # processing flow keeps the affected partition paused and its offsets uncommitted, so after
    # the restart the failed work is redelivered - the stop initiated here is what converts that
    # containment into the actual process replacement.
    #
    # It is auto-subscribed as part of Karafka itself.
    class CriticalErrorsListener
      include Singleton
      include Helpers::ConfigImporter.new(
        critical_errors: %i[internal processing critical_errors]
      )

      # Sets up the one-shot initiation state
      def initialize
        @mutex = Mutex.new
        @initiated = false
      end

      # Re-arms the listener when the app (re)starts so in-process restarts (embedded mode,
      # integration flows) can escalate again
      # @param _event [Karafka::Core::Monitoring::Event]
      def on_app_running(_event)
        @mutex.synchronize { @initiated = false }
      end

      # @param event [Karafka::Core::Monitoring::Event] error.occurred event. Its `:error` key
      #   carries the error that was reported.
      def on_error_occurred(event)
        error = event[:error]

        return unless critical_errors.any? { |type| error.is_a?(type) }

        # The one-shot flag makes the check-and-spawn atomic: critical errors reported by many
        # consumers at the same moment (or a duplicated bus subscription) spawn exactly one
        # supervising stop thread
        @mutex.synchronize do
          return if @initiated
          # No need to initiate the stop if one is already in motion (shutdown requested before
          # the error surfaced). We deliberately do not use `App.done?` here: it includes the
          # quieting/quiet states, in which the process is parked but alive - a critical error
          # raised by in-flight work during quiet must still escalate to a full stop
          return if Karafka::App.stopping?
          return if Karafka::App.stopped?
          return if Karafka::App.terminated?

          @initiated = true

          # `Karafka::Server.stop` supervises the whole shutdown (including the forceful timeout
          # path), so it runs from a dedicated thread: the reporting thread must return so the
          # processing flow can finish and engage the pause that protects the affected partition
          # during the shutdown window
          Thread.new do
            Thread.current.name = "karafka.critical_shutdown"

            Karafka::Server.stop
          end
        end
      # The spawn itself can fail exactly under the conditions this listener handles (e.g.
      # NoMemoryError, ThreadError at the thread limit). It must never escape: an error raised
      # from an `error.occurred` subscriber would propagate into the reporting flow and could
      # bypass the containment that protects the failed batch. We leave a best-effort fatal
      # trace because in this degenerate state the process will NOT shut down despite the
      # critical error - without it the why would be undiagnosable
      rescue Exception
        begin
          Karafka.logger.fatal(
            "Failed to initiate the critical error shutdown - process continues without it"
          )
        rescue Exception
          nil
        end
      end
    end
  end
end
