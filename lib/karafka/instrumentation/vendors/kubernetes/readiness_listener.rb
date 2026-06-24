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
          # @param port [Integer] TCP port on which we want to run our HTTP status server. Use a
          #   port different from the liveness listener (and from Puma when embedding).
          def initialize(
            hostname: nil,
            port: 3000
          )
            @mutex = Mutex.new
            # Ids of subscription groups that have polled at least once.
            @polled_groups = Set.new
            # Latched once every active subscription group has polled. It only ever goes
            # false -> true; readiness then also depends on the process not being `done?` (see
            # #healthy?), which is what lets the probe report not-ready again during shutdown.
            @all_groups_polled = false
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

          # Record that a subscription group has polled, and latch once all active subscription
          # groups have polled at least once.
          # @param event [Karafka::Core::Monitoring::Event] carries the `:subscription_group`
          def on_connection_listener_fetch_loop(event)
            group_id = event[:subscription_group]&.id

            return unless group_id

            synchronize do
              @polled_groups << group_id
              # Once latched, skip recomputing the expected set on every subsequent poll.
              @all_groups_polled ||= all_active_groups_polled?
            end
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

            synchronize { @all_groups_polled }
          end

          # @return [Boolean] whether every active subscription group has polled at least once.
          # @note Caller must hold `@mutex` (reads `@polled_groups`).
          def all_active_groups_polled?
            expected = expected_group_ids

            # If the expected set cannot be determined (routes not drawn, or an unexpected error),
            # fall back to "at least one group polled" so a discovery failure can never wedge a pod
            # into never-ready.
            return @polled_groups.any? if expected.nil? || expected.empty?

            expected.subset?(@polled_groups)
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
