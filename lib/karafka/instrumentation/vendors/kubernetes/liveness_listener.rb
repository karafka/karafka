# frozen_string_literal: true

require "karafka/instrumentation/vendors/kubernetes/base_listener"

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
          # @param stability_ttl [Integer] max time in ms a subscription group can remain in the
          #   same tracked non-"steady" librdkafka `cgrp.join_state` (e.g. `wait-join`, `wait-assn`,
          #   `wait-sync`) before the process is considered unhealthy. `wait-metadata` is excluded
          #   because it appears in normal scenarios (auto-create waits, unmatched pattern
          #   subscriptions, and as the group leader's post-JoinGroup state while fetching cluster
          #   metadata to compute the partition assignment) — not only during stuck rebalances.
          #   `init` is handled by clearing stale tracking on client reset rather than by
          #   skipping. Both states are covered by `polling_ttl` for genuine freezes.
          #   The timer resets on every join_state transition between tracked states because any
          #   change indicates the join protocol is still progressing; only a consumer frozen in
          #   the same non-steady state continuously triggers the alarm. Note that a consumer
          #   cycling rapidly between non-steady states (e.g. wait-join → wait-assn → wait-join)
          #   will not trip this check — it only catches consumers stuck in one state.
          #   Should be set to at least your `max.poll.interval.ms` (default 300,000 ms) to avoid
          #   false positives during slow but legitimate instabilities. The default of 10 minutes
          #   provides headroom above the Kafka default. Requires `statistics.interval.ms` to be
          #   configured in the Kafka client settings; without it `statistics.emitted` never fires,
          #   tracking hashes remain empty, and this check has no effect (no misreporting).
          def initialize(
            hostname: nil,
            port: 3000,
            consuming_ttl: 5 * 60 * 1_000,
            polling_ttl: 5 * 60 * 1_000,
            stability_ttl: 10 * 60 * 1_000
          )
            # If this is set to a symbol, it indicates unrecoverable error like fencing
            # While fencing can be partial (for one of the SGs), we still should consider this
            # as an undesired state for the whole process because it halts processing in a
            # non-recoverable manner forever
            @unrecoverable = false
            @polling_ttl = polling_ttl
            @consuming_ttl = consuming_ttl
            @stability_ttl = stability_ttl
            @mutex = Mutex.new
            @pollings = {}
            @consumptions = {}
            # Maps subscription_group_id => last observed cgrp.join_state string.
            # Used to detect state changes so the stuck timer resets on any transition.
            # Both hashes are only populated by on_statistics_emitted, which requires
            # statistics.interval.ms to be set. Without it they remain empty and
            # stability_ttl_exceeded? always returns false - no misreporting.
            @join_states = {}
            # Maps subscription_group_id => monotonic_now when the current non-steady state began.
            @instabilities = {}
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

          # Track when each subscription group's consumer enters or leaves a non-steady join state.
          # A prolonged non-steady state (e.g., wait-join, wait-assn caused by a broker stuck in
          # CompletingRebalance) is reported as unhealthy.
          #
          # `wait-metadata` is skipped: it appears in normal scenarios (auto-create waits, unmatched
          # pattern subscriptions, and as the group leader's post-JoinGroup state while fetching
          # cluster metadata to compute the partition assignment), not only during stuck rebalances.
          # `polling_ttl` covers genuine freezes in that state.
          #
          # `init` clears stale tracking so that a client reset or subscription-group removal
          # (e.g., dynamic multiplexing scale-down) does not leave a persistent false-positive entry.
          #
          # The stuck timer resets on every transition between tracked states because any change
          # indicates the join protocol is still progressing. Only a consumer frozen in the same
          # non-steady state continuously for stability_ttl is flagged. Note that a consumer
          # cycling rapidly between non-steady states (e.g. wait-join → wait-assn → wait-join)
          # will not trip this alarm — only a frozen-in-one-state consumer is caught.
          # @param event [Karafka::Core::Monitoring::Event]
          def on_statistics_emitted(event)
            cgrp = event[:statistics]["cgrp"]
            return unless cgrp

            sg_id = event[:subscription_group_id]
            join_state = cgrp["join_state"]
            return unless join_state

            # "wait-metadata" appears in multiple normal scenarios (auto-create waits, unmatched
            # pattern subscriptions, and as the group leader's post-JoinGroup state while fetching
            # cluster metadata to compute assignments). Skip it to avoid false positives;
            # polling_ttl covers genuine freezes in this state.
            return if join_state == "wait-metadata"

            synchronize do
              if join_state == "steady" || join_state == "init"
                # "init" clears any stale entry when the subscription group's rdkafka client
                # resets (e.g., after a scale-down or pattern unsubscribe), preventing a
                # persistent false positive for entries that would otherwise only clear on "steady".
                @instabilities.delete(sg_id)
                @join_states.delete(sg_id)
              elsif @join_states[sg_id] != join_state
                @join_states[sg_id] = join_state
                @instabilities[sg_id] = monotonic_now
              end
            end
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

          # @param event [Karafka::Core::Monitoring::Event]
          def on_error_occurred(event)
            clear_consumption_tick
            clear_polling_tick

            error = event[:error]

            # We are only interested in the rdkafka errors
            return unless error.is_a?(Rdkafka::RdkafkaError)
            # When any of those occurs, it means something went wrong in a way that cannot be
            # recovered. In such cases we should report that the consumer process is not healthy.
            return unless error.fatal?

            @unrecoverable = error.code
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

          # Did we exceed any of the ttls
          # @return [String] 204 string if ok, 500 otherwise
          def healthy?
            return false if @unrecoverable
            return false if polling_ttl_exceeded?
            return false if consuming_ttl_exceeded?
            return false if stability_ttl_exceeded?

            true
          end

          private

          # @return [Boolean] true if the consumer exceeded the polling ttl
          def polling_ttl_exceeded?
            time = monotonic_now
            synchronize { @pollings.values.any? { |tick| (time - tick) > @polling_ttl } }
          end

          # @return [Boolean] true if the consumer exceeded the consuming ttl
          def consuming_ttl_exceeded?
            time = monotonic_now
            synchronize { @consumptions.values.any? { |tick| (time - tick) > @consuming_ttl } }
          end

          # @return [Boolean] true if any subscription group has been stuck in a non-steady
          #   librdkafka join state for longer than the configured stability TTL
          def stability_ttl_exceeded?
            time = monotonic_now
            synchronize { @instabilities.values.any? { |start| (time - start) > @stability_ttl } }
          end

          # Wraps the logic with a mutex
          def synchronize(&)
            @mutex.synchronize(&)
          end

          # @return [Integer] object id of the current fiber
          # @note We use fiber object id instead of thread object id to ensure fiber-safety.
          #   Multiple fibers can run on the same thread, and using thread id would cause them
          #   to overwrite each other's timestamps.
          def fiber_id
            Fiber.current.object_id
          end

          # Update the polling tick time for current fiber
          def mark_polling_tick
            synchronize do
              @pollings[fiber_id] = monotonic_now
            end
          end

          # Clear current fiber polling time tracker
          def clear_polling_tick
            synchronize do
              @pollings.delete(fiber_id)
            end
          end

          # Update the processing tick time
          def mark_consumption_tick
            synchronize do
              @consumptions[fiber_id] = monotonic_now
            end
          end

          # Clear current fiber consumption time tracker
          def clear_consumption_tick
            synchronize do
              @consumptions.delete(fiber_id)
            end
          end

          # @return [Hash] response body status
          def status_body
            super.merge!(
              errors: {
                polling_ttl_exceeded: polling_ttl_exceeded?,
                consumption_ttl_exceeded: consuming_ttl_exceeded?,
                stability_ttl_exceeded: stability_ttl_exceeded?,
                unrecoverable: @unrecoverable
              }
            )
          end
        end
      end
    end
  end
end
