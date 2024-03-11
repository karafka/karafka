# frozen_string_literal: true

require 'karafka/instrumentation/vendors/kubernetes/base_listener'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for instrumentation related with Kubernetes
      module Kubernetes
        # Kubernetes HTTP listener that does not only reply when process is not fully hanging, but
        # also allows to define max time of processing and looping.
        #
        # Processes like Karafka server can hang while still being reachable. For example, in case
        # something would hang inside of the user code, Karafka could stop polling and no new
        # data would be processed, but process itself would still be active. This listener allows
        # for defining of a ttl that gets bumped on each poll loop and before and after processing
        # of a given messages batch.
        #
        # @note This listener will bind itself only when Karafka will actually attempt to start
        #   and moves from initializing to running. Before that, the TCP server will NOT be active.
        #   This is done on purpose to mitigate a case where users would subscribe this listener
        #   in `karafka.rb` without checking the recommendations of conditional assignment.
        #
        # @note In case of usage within an embedding with Puma, you need to select different port
        #   then the one used by Puma itself.
        #
        # @note Please use `Kubernetes::SwarmLivenessListener` when operating in the swarm mode
        class LivenessListener < BaseListener
          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server
          # @param consuming_ttl [Integer] time in ms after which we consider consumption hanging.
          #   It allows us to define max consumption time after which k8s should consider given
          #   process as hanging
          # @param polling_ttl [Integer] max time in ms for polling. If polling (any) does not
          #   happen that often, process should be considered dead.
          # @note The default TTL matches the default `max.poll.interval.ms`
          def initialize(
            hostname: nil,
            port: 3000,
            consuming_ttl: 5 * 60 * 1_000,
            polling_ttl: 5 * 60 * 1_000
          )
            @polling_ttl = polling_ttl
            @consuming_ttl = consuming_ttl
            @mutex = Mutex.new
            @pollings = {}
            @consumptions = {}
            super(hostname: hostname, port: port)
          end

          # @param _event [Karafka::Core::Monitoring::Event]
          def on_app_running(_event)
            start
          end

          # Stop the http server when we stop the process
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_app_stopped(_event)
            stop
          end

          # Tick on each fetch
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

          # Wraps the logic with a mutex
          # @param block [Proc] code we want to run in mutex
          def synchronize(&block)
            @mutex.synchronize(&block)
          end

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
          def healthy?
            time = monotonic_now

            return false if @pollings.values.any? { |tick| (time - tick) > @polling_ttl }
            return false if @consumptions.values.any? { |tick| (time - tick) > @consuming_ttl }

            true
          end
        end
      end
    end
  end
end
