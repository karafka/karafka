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

      # @param event [Karafka::Core::Monitoring::Event] error.occurred event. Its `:error` key
      #   carries the error that was reported.
      def on_error_occurred(event)
        error = event[:error]

        return unless critical_errors.any? { |type| error.is_a?(type) }
        # No need to initiate the stop if one is already in motion (e.g. critical errors
        # reported by multiple consumers at the same time or shutdown already requested). We
        # deliberately do not use `App.done?` here: it includes the quieting/quiet states, in
        # which the process is parked but alive - a critical error raised by in-flight work
        # during quiet must still escalate to a full stop
        return if Karafka::App.stopping?
        return if Karafka::App.stopped?
        return if Karafka::App.terminated?

        # `Karafka::Server.stop` supervises the whole shutdown (including the forceful timeout
        # path), so it runs from a dedicated thread: the reporting thread must return so the
        # processing flow can finish and engage the pause that protects the affected partition
        # during the shutdown window
        Thread.new do
          Thread.current.name = "karafka.critical_shutdown"

          Karafka::Server.stop
        end
      # The spawn itself can fail exactly under the conditions this listener handles (e.g.
      # NoMemoryError, ThreadError at the thread limit). It must never escape: an error raised
      # from an `error.occurred` subscriber would propagate into the reporting flow and could
      # bypass the containment that protects the failed batch. The original error was already
      # instrumented, so there is nothing more we can reliably do here
      rescue Exception
        nil
      end
    end
  end
end
