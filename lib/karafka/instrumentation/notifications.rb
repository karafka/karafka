# frozen_string_literal: true

module Karafka
  # Namespace for all the things related with Karafka instrumentation process
  module Instrumentation
    # Monitor is used to hookup external monitoring services to monitor how Karafka works
    # It provides a standardized API for checking incoming messages/enqueueing etc
    # Since it is a pub-sub based on dry-monitor, you can use as many subscribers/loggers at the
    # same time, which means that you might have for example file logging and NewRelic at the same
    # time
    # @note This class acts as a singleton because we are only permitted to have single monitor
    #   per running process (just as logger)
    class Notifications < Karafka::Core::Monitoring::Notifications
      # List of events that we support in the system and to which a monitor client can hook up
      # @note The non-error once support timestamp benchmarking
      # @note Depending on Karafka extensions and additional engines, this might not be the
      #   complete list of all the events. Please use the #available_events on fully loaded
      #   Karafka system to determine all of the events you can use.
      EVENTS = %w[
        active_job.consume
        active_job.consumed

        app.initializing
        app.initialized
        app.before_warmup
        app.supervising
        app.running
        app.quieting
        app.quiet
        app.stopping
        app.stopped
        app.terminated

        client.pause
        client.resume
        client.reset

        connection.listener.before_fetch_loop
        connection.listener.fetch_loop
        connection.listener.fetch_loop.received
        connection.listener.after_fetch_loop

        connection.listener.pending
        connection.listener.starting
        connection.listener.running
        connection.listener.quieting
        connection.listener.quiet
        connection.listener.stopping
        connection.listener.stopped

        consumer.initialize
        consumer.initialized

        consumer.before_schedule_consume
        consumer.consume
        consumer.consumed
        consumer.consuming.pause
        consumer.consuming.retry
        consumer.consuming.seek
        consumer.consuming.transaction

        consumer.before_schedule_idle
        consumer.idle

        consumer.before_schedule_revoked
        consumer.revoke
        consumer.revoked

        consumer.before_schedule_tick
        consumer.tick
        consumer.ticked

        consumer.before_schedule_eofed
        consumer.eof
        consumer.eofed

        consumer.before_schedule_shutdown
        consumer.shutting_down
        consumer.shutdown

        consumer.wrap
        consumer.wrapped

        dead_letter_queue.dispatched

        filtering.throttled
        filtering.seek

        oauthbearer.token_refresh

        process.notice_signal

        rebalance.partitions_assign
        rebalance.partitions_assigned
        rebalance.partitions_revoke
        rebalance.partitions_revoked

        statistics.emitted

        swarm.node.after_fork
        swarm.manager.before_fork
        swarm.manager.after_fork
        swarm.manager.control
        swarm.manager.stopping
        swarm.manager.terminating

        worker.process
        worker.processed
        worker.completed

        error.occurred
      ].freeze

      # @return [Karafka::Instrumentation::Monitor] monitor instance for system instrumentation
      def initialize
        super
        EVENTS.each { |event| register_event(event) }
      end
    end
  end
end
