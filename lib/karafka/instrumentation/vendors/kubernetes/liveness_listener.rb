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
          # Default time in ms after which we consider consumption hanging (5 minutes)
          DEFAULT_CONSUMING_TTL = 5 * 60 * 1_000
          # Default max time in ms between polls before the process is considered dead (5 minutes)
          DEFAULT_POLLING_TTL = 5 * 60 * 1_000
          # Multiplier applied to max.poll.interval.ms when deriving the default stability_ttl.
          # 2x gives headroom above the slowest legitimate rebalance phase (cooperative
          # `wait-unassign-to-complete` can approach max.poll.interval.ms).
          STABILITY_TTL_MAX_POLL_MULTIPLIER = 2

          private_constant(
            :DEFAULT_CONSUMING_TTL,
            :DEFAULT_POLLING_TTL,
            :STABILITY_TTL_MAX_POLL_MULTIPLIER
          )

          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server
          # @param consuming_ttl [Integer] time in ms after which we consider consumption hanging.
          #   It allows us to define max consumption time after which k8s should consider given
          #   process as hanging
          # @param polling_ttl [Integer] max time in ms for polling. If polling (any) does not
          #   happen that often, process should be considered dead.
          # @param stability_ttl [Integer, nil] max time in ms a subscription group can remain in
          #   the same tracked non-"steady" librdkafka `cgrp.join_state` (e.g. `wait-join`,
          #   `wait-assn`, `wait-sync`) before the process is considered unhealthy. When nil
          #   (default), it is derived from `Karafka::App.config.kafka[:'max.poll.interval.ms']` as
          #   `max.poll.interval.ms * 2`, which keeps the threshold safe relative to the user's
          #   actual poll interval rather than a fixed constant. `wait-metadata` and `init` are
          #   excluded from tracking and additionally clear any stale prior tracking for the
          #   subscription group: `wait-metadata` appears in normal scenarios (auto-create waits,
          #   unmatched pattern subscriptions, and as the group leader's post-JoinGroup state while
          #   fetching cluster metadata to compute the partition assignment); `init` indicates a
          #   client reset. Both states are covered by `polling_ttl` for genuine freezes.
          #   The timer resets on every join_state transition between tracked states because any
          #   change indicates the join protocol is still progressing; only a consumer frozen in
          #   the same non-steady state continuously triggers the alarm. A consumer cycling
          #   rapidly between non-steady states (e.g. wait-join -> wait-assn -> wait-join) will
          #   not trip this check - it only catches consumers frozen in a single join state.
          #   Requires `statistics.interval.ms` to be configured in the Kafka client settings;
          #   without it `statistics.emitted` never fires, tracking hashes remain empty, and this
          #   check has no effect (no misreporting).
          def initialize(
            hostname: nil,
            port: 3000,
            consuming_ttl: DEFAULT_CONSUMING_TTL,
            polling_ttl: DEFAULT_POLLING_TTL,
            stability_ttl: nil
          )
            # If this is set to a symbol, it indicates unrecoverable error like fencing
            # While fencing can be partial (for one of the SGs), we still should consider this
            # as an undesired state for the whole process because it halts processing in a
            # non-recoverable manner forever
            @unrecoverable = false
            @polling_ttl = polling_ttl
            @consuming_ttl = consuming_ttl
            @stability_ttl = stability_ttl || default_stability_ttl
            @mutex = Mutex.new
            @pollings = {}
            @consumptions = {}
            # Maps subscription_group_id => last observed cgrp.join_state string.
            # Used to detect state changes so the stuck timer resets on any transition.
            # Both hashes are only populated by on_statistics_emitted, which requires
            # statistics.interval.ms to be set. Without it they remain empty and the
            # stability flag in evaluate_ttl_flags is always false - no misreporting.
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
          # `steady`, `init`, and `wait-metadata` all clear any stale tracking for the subscription
          # group rather than skip the event. Clearing on `wait-metadata` matters because the
          # state legitimately appears mid-join (leader fetching cluster metadata to compute
          # assignment), during auto-create waits, and on unmatched pattern subscriptions - if we
          # only `return` from these the previous non-steady timer keeps running and eventually
          # trips a false positive. Clearing on `init` covers client resets / subscription-group
          # removal. Genuine freezes in these states are covered by `polling_ttl`.
          #
          # The stuck timer resets on every transition between tracked states because any change
          # indicates the join protocol is still progressing. Only a consumer frozen in the same
          # non-steady state continuously for stability_ttl is flagged. A consumer cycling
          # rapidly between non-steady states (e.g. wait-join -> wait-assn -> wait-join) will not
          # trip this alarm - only a frozen-in-one-state consumer is caught.
          # @param event [Karafka::Core::Monitoring::Event]
          def on_statistics_emitted(event)
            cgrp = event[:statistics]&.dig("cgrp")
            return unless cgrp

            sg_id = event[:subscription_group_id]
            join_state = cgrp["join_state"]
            return unless join_state

            synchronize do
              if join_state == "steady" || join_state == "init" || join_state == "wait-metadata"
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
          # @return [Boolean] true if all TTLs are within bounds and no unrecoverable error
          def healthy?
            return false if @unrecoverable

            flags = evaluate_ttl_flags
            !flags[:polling] && !flags[:consuming] && !flags[:stability]
          end

          private

          # Single-snapshot evaluation of all three TTL flags under one lock. Used by both
          # `healthy?` and `status_body` so the HTTP status code (derived from healthy?) and the
          # error details in the response body are always derived from the same atomic snapshot.
          # @return [Hash{Symbol => Boolean}] flags for polling, consuming and stability
          def evaluate_ttl_flags
            time = monotonic_now
            synchronize do
              {
                polling: @pollings.values.any? { |tick| (time - tick) > @polling_ttl },
                consuming: @consumptions.values.any? { |tick| (time - tick) > @consuming_ttl },
                stability: @instabilities.values.any? { |start| (time - start) > @stability_ttl }
              }
            end
          end

          # @return [Integer] default stability_ttl derived from the configured
          #   max.poll.interval.ms (with librdkafka's default applied by `DefaultsInjector`
          #   when the user has not set it), multiplied by 2 for headroom above the slowest
          #   legitimate rebalance phase.
          def default_stability_ttl
            # DefaultsInjector#consumer mutates a kafka config hash to ensure
            # max.poll.interval.ms is set (using the same librdkafka default Karafka injects per
            # subscription group). We dup so we don't mutate the global config.
            kafka_config = Karafka::App.config.kafka.dup
            Karafka::Setup::DefaultsInjector.consumer(kafka_config)
            kafka_config.fetch(:"max.poll.interval.ms") * STABILITY_TTL_MAX_POLL_MULTIPLIER
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

          # @return [Hash] response body status. The healthy/unhealthy decision and the per-flag
          #   error details are derived from a single locked snapshot so the HTTP status and
          #   body always agree (avoids the previous pattern of taking the lock six times per
          #   response which could observe state changes between acquisitions).
          def status_body
            unrecoverable = @unrecoverable
            flags = evaluate_ttl_flags
            is_healthy = !unrecoverable && !flags[:polling] && !flags[:consuming] && !flags[:stability]

            {
              status: is_healthy ? "healthy" : "unhealthy",
              timestamp: Time.now.to_i,
              port: @port,
              process_id: ::Process.pid,
              errors: {
                polling_ttl_exceeded: flags[:polling],
                consumption_ttl_exceeded: flags[:consuming],
                stability_ttl_exceeded: flags[:stability],
                unrecoverable: unrecoverable
              }
            }
          end
        end
      end
    end
  end
end
