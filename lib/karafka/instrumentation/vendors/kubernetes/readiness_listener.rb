# frozen_string_literal: true

require "karafka/instrumentation/vendors/kubernetes/base_listener"

module Karafka
  module Instrumentation
    module Vendors
      module Kubernetes
        # Kubernetes HTTP listener for a readiness probe: it reports healthy once the consumer has
        # started polling, and reports not-ready again once the process begins shutting down or
        # quieting. Subscribe it alongside {LivenessListener} (on a separate port) and point a
        # `startupProbe` / `readinessProbe` at this one and a `livenessProbe` at {LivenessListener}.
        #
        # Healthy is reported when both of these hold:
        #
        # * every active subscription group has emitted at least one
        #   `connection.listener.fetch_loop` - a Karafka process runs one listener thread per
        #   subscription group, each emitting its own fetch loop, so waiting for all active groups
        #   reports Ready only once each group has started polling; and
        # * the process is not in a `done?` state (`quieting`, `quiet`, `stopping`, `stopped` or
        #   `terminated`).
        #
        # The "all groups have polled" condition latches once satisfied, so transient poll-tracking
        # changes do not flip it back; the `done?` condition is re-evaluated on each request, so a
        # quieting or stopping process is reported not-ready and Kubernetes can remove it from the
        # Service endpoints before it exits.
        #
        # @note The TCP server binds when Karafka moves from initializing to running
        #   (`app_running`). Before that the server is not listening, so the probe receives a
        #   connection refusal, which a `startupProbe` treats as not-ready.
        #
        # @note When embedding alongside a web server (e.g. Puma), pick a port different from both
        #   Puma and the liveness listener.
        #
        # @example Subscribe a readiness probe on its own port (alongside a liveness probe)
        #   Karafka.monitor.subscribe(
        #     Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(port: 3000)
        #   )
        #   Karafka.monitor.subscribe(
        #     Karafka::Instrumentation::Vendors::Kubernetes::ReadinessListener.new(port: 3001)
        #   )
        class ReadinessListener < BaseListener
          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server. Defaults
          #   to 3001 (one above the {LivenessListener} default of 3000) so both can be subscribed
          #   together out of the box without colliding. Use a port different from the liveness
          #   listener (and from Puma when embedding).
          def initialize(
            hostname: nil,
            port: 3001
          )
            @mutex = Mutex.new
            # Ids of subscription groups that have polled at least once.
            @polled_groups = Set.new
            # Latched once every active subscription group has polled. It only ever goes
            # false -> true; readiness then also depends on the process not being `done?` (see
            # #healthy?), which is what lets the probe report not-ready again during shutdown.
            @all_groups_polled = false
            # One-shot guard so a persistent subscription-group discovery error, re-evaluated on
            # every poll/probe, is logged once instead of on every tick.
            @discovery_error_reported = false
            # Holds a single healthy? snapshot for the duration of a #status_body call so the HTTP
            # status code and the body's `ready` field agree; nil at all other times.
            @health_snapshot = nil
            super
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

          # Record that a subscription group has polled. This runs on every poll iteration (the hot
          # path), so it is kept deliberately cheap: it only tracks the polled group id and does
          # *not* evaluate the readiness gate here (which would call
          # `Karafka::App.subscription_groups` and rebuild the expected set on every tick until
          # latched). Latching of `@all_groups_polled` happens lazily the next time the probe calls
          # `#healthy?` / `#status_body` - the only places the gate is actually observed - so moving
          # it off the poll loop changes nothing an external caller can see.
          # @param event [Karafka::Core::Monitoring::Event] carries the `:subscription_group`
          def on_connection_listener_fetch_loop(event)
            group_id = event[:subscription_group]&.id

            return unless group_id

            synchronize { @polled_groups << group_id }
          end

          # @return [Boolean] true when every active subscription group has polled at least once
          #   and the process is not shutting down or quieting. The first condition latches; the
          #   second (`Karafka::App.done?`) is re-checked on each call, so the probe reports
          #   not-ready as soon as the process starts draining.
          # @note When called from inside `#status_body`, reuses the cached value taken there so the
          #   HTTP status code and the `ready` field in the body come from the same snapshot.
          def healthy?
            return @health_snapshot unless @health_snapshot.nil?

            evaluate_healthy
          end

          private

          # @return [Boolean] the actual readiness evaluation (not the cached snapshot).
          def evaluate_healthy
            return false if Karafka::App.done?

            synchronize { ready_without_drain? }
          end

          # @return [Boolean] whether the consumer is ready, ignoring the drain (`done?`) check
          #   that #evaluate_healthy layers on top: true once every active subscription group has
          #   polled at least once.
          # @note Caller must hold `@mutex` (reads `@polled_groups`, may set the latch).
          #
          # The authoritative "every expected group has polled" gate latches once met, so a later
          # rebalance cannot flip readiness back off. Until that gate can be evaluated (the expected
          # subscription-group set is not yet determinable), we fall back to "at least one group
          # polled", evaluated live and *not* latched - so the authoritative gate takes over as soon
          # as the expected set becomes available, and a transient discovery gap can no longer
          # permanently latch readiness on a single poll.
          def ready_without_drain?
            return true if @all_groups_polled

            expected = expected_group_ids

            # Expected set not determinable (routes not drawn yet, or a discovery error): live
            # fallback so a discovery failure can never wedge a pod into never-ready, while never
            # latching on this incomplete picture.
            return @polled_groups.any? if expected.nil? || expected.empty?

            # Authoritative gate: latch once satisfied.
            @all_groups_polled = expected.subset?(@polled_groups)
          end

          # @return [Set<String>, nil] ids of the subscription groups this process will run, or nil
          #   when not yet determinable. `Karafka::App.subscription_groups` already
          #   reflects the CLI `--include`/`--exclude` filtering and its ids match the ones carried
          #   on each `connection.listener.fetch_loop` event, so comparing the polled set against it
          #   is an accurate "all groups online" gate. Resolved lazily (not in `#initialize`)
          #   because routing may not be drawn yet when the listener is constructed in `karafka.rb`.
          def expected_group_ids
            ids = Karafka::App.subscription_groups.values.flatten.map(&:id)
            return nil if ids.empty?

            Set.new(ids)
          rescue => e
            # Never let a discovery failure wedge the pod (the caller falls back to "any group
            # polled"), but surface the error once so a genuine bug here stays diagnosable instead
            # of being silently masked behind the fallback forever.
            report_discovery_error(e)
            nil
          end

          # Log a subscription-group discovery error once (it recurs on every poll/probe while the
          # failure persists, so repeated logging would just be noise). We log directly rather than
          # dispatching on the shared `error.occurred` bus: that bus invokes every other subscriber
          # (e.g. a co-subscribed LivenessListener, which reacts to it) and does not rescue their
          # exceptions, so emitting it from inside the fetch-loop handler could both perturb
          # unrelated listeners and let a raising subscriber escape into the polling loop - the very
          # wedge this rescue exists to prevent. The log call is itself guarded so nothing here can
          # escape.
          # @param error [StandardError] the swallowed discovery error
          # @note Caller must hold `@mutex` (reads and sets `@discovery_error_reported`).
          def report_discovery_error(error)
            return if @discovery_error_reported

            @discovery_error_reported = true

            Karafka.logger.error(
              "ReadinessListener could not determine the expected subscription groups " \
              "(#{error.class}: #{error.message}); falling back to 'at least one group polled'"
            )
          rescue
            nil
          end

          # Wraps the logic with a mutex
          def synchronize(&)
            @mutex.synchronize(&)
          end

          # @return [Hash] response body status, extending the base envelope with readiness details
          #   so an operator inspecting the endpoint can see how many groups have polled.
          # @note Takes a single readiness snapshot and caches it for the duration of the call so
          #   the base envelope's `status` (and the HTTP status code derived from it) and the
          #   merged `ready` field are computed from the same value.
          def status_body
            @health_snapshot = evaluate_healthy
            polled, expected = synchronize { [@polled_groups.size, expected_group_ids&.size] }

            super.merge!(
              ready: @health_snapshot,
              polled_subscription_groups: polled,
              expected_subscription_groups: expected
            )
          ensure
            @health_snapshot = nil
          end
        end
      end
    end
  end
end
