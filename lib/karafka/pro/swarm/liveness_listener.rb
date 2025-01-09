# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Pro Swarm components namespace
    module Swarm
      # Pro listener that monitors RSS usage and other heartbeat metrics (if configured) to ensure
      # that everything operates.
      #
      # It can:
      #   - monitor poll frequency to make sure things are not polled not often enough
      #   - monitor consumption to make sure we do not process data for too long
      #   - monitor RSS to make sure that we do not use too much memory
      #
      # By default it does **not** monitor memory and consuming and polling is configured in such
      # a way to align with `max.poll.interval.ms` and other defaults.
      #
      # Failure statuses reported are as follows:
      #   - 1 - polling ttl exceeded
      #   - 2 - consuming ttl exceeded
      #   - 3 - memory limit exceeded
      #
      # @note This listener should not break anything if subscribed in the supervisor prior to
      #   forking as it relies on server events for operations.
      class LivenessListener < Karafka::Swarm::LivenessListener
        # @param memory_limit [Integer] max memory in MB for this process to be considered healthy
        # @param consuming_ttl [Integer] time in ms after which we consider consumption hanging.
        #   It allows us to define max consumption time after which supervisor should consider
        #   given process as hanging
        # @param polling_ttl [Integer] max time in ms for polling. If polling (any) does not
        #   happen that often, process should be considered dead.
        # @note The default TTL matches the default `max.poll.interval.ms`
        def initialize(
          memory_limit: Float::INFINITY,
          consuming_ttl: 5 * 60 * 1_000,
          polling_ttl: 5 * 60 * 1_000
        )
          @polling_ttl = polling_ttl
          @consuming_ttl = consuming_ttl
          # We cast it just in case someone would provide '10MB' or something similar
          @memory_limit = memory_limit.is_a?(String) ? memory_limit.to_i : memory_limit
          @pollings = {}
          @consumptions = {}

          super()
        end

        # Tick on each fetch
        #
        # @param _event [Karafka::Core::Monitoring::Event]
        def on_connection_listener_fetch_loop(_event)
          mark_polling_tick
        end

        {
          consume: :consumed,
          revoke: :revoked,
          shutting_down: :shutdown,
          tick: :ticked
        }.each do |before, after|
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            # Tick on starting work
            # @param _event [Karafka::Core::Monitoring::Event]
            def on_consumer_#{before}(_event)
              mark_consumption_tick
            end

            # Tick on finished work
            # @param _event [Karafka::Core::Monitoring::Event]
            def on_consumer_#{after}(_event)
              clear_consumption_tick
            end
          RUBY
        end

        # @param _event [Karafka::Core::Monitoring::Event]
        def on_error_occurred(_event)
          clear_consumption_tick
          clear_polling_tick
        end

        # Reports the current status once in a while
        #
        # @param _event [Karafka::Core::Monitoring::Event]
        def on_statistics_emitted(_event)
          periodically do
            return unless node

            current_status = status

            current_status.positive? ? node.unhealthy(current_status) : node.healthy
          end
        end

        # Deregister the polling tracker for given listener
        # @param _event [Karafka::Core::Monitoring::Event]
        def on_connection_listener_stopping(_event)
          # We are interested in disabling tracking for given listener only if it was requested
          # when karafka was running. If we would always clear, it would not catch the shutdown
          # polling requirements. The "running" listener shutdown operations happen only when
          # the manager requests it for downscaling.
          return if Karafka::App.done?

          clear_polling_tick
        end

        # Deregister the polling tracker for given listener
        # @param _event [Karafka::Core::Monitoring::Event]
        def on_connection_listener_stopped(_event)
          return if Karafka::App.done?

          clear_polling_tick
        end

        private

        # @return [Integer] object id of the current thread
        def thread_id
          Thread.current.object_id
        end

        # Update the polling tick time for current thread
        def mark_polling_tick
          synchronize do
            @pollings[thread_id] = monotonic_now
          end
        end

        # Clear current thread polling time tracker
        def clear_polling_tick
          synchronize do
            @pollings.delete(thread_id)
          end
        end

        # Update the processing tick time
        def mark_consumption_tick
          synchronize do
            @consumptions[thread_id] = monotonic_now
          end
        end

        # Clear current thread consumption time tracker
        def clear_consumption_tick
          synchronize do
            @consumptions.delete(thread_id)
          end
        end

        # Did we exceed any of the ttls
        # @return [String] 204 string if ok, 500 otherwise
        def status
          time = monotonic_now

          return 1 if @pollings.values.any? { |tick| (time - tick) > @polling_ttl }
          return 2 if @consumptions.values.any? { |tick| (time - tick) > @consuming_ttl }
          return 3 if rss_mb > @memory_limit

          0
        end

        # @return [Integer] RSS in MB for the current process
        # @note Since swarm is linux only, we do not have to worry about getting RSS on other OSes
        def rss_mb
          kb_rss = 0

          IO.readlines("/proc/#{node.pid}/status").each do |line|
            next unless line.start_with?('VmRSS:')

            kb_rss = line.split[1].to_i

            break
          end

          (kb_rss / 1_024.to_i).round
        end
      end
    end
  end
end
