# frozen_string_literal: true

module Karafka
  module Swarm
    # Manager similar to the one for threads but managing processing nodes
    # It starts nodes and keeps an eye on them.
    #
    # In any of the nodes is misbehaving (based on liveness listener) it will be restarted.
    # Initially gracefully but if won't stop itself, it will be forced to.
    #
    # @note This is intended to run in the supervisor under mutexes (when needed)
    class Manager
      include Karafka::Core::Helpers::Time
      include Helpers::ConfigImporter.new(
        monitor: %i[monitor],
        nodes_count: %i[swarm nodes],
        shutdown_timeout: %i[shutdown_timeout],
        node_report_timeout: %i[internal swarm node_report_timeout],
        node_restart_timeout: %i[internal swarm node_restart_timeout]
      )

      # Status we issue when we decide to shutdown unresponsive node
      # We use -1 because nodes are expected to report 0+ statuses and we can use negative numbers
      # for non-node based statuses
      NOT_RESPONDING_SHUTDOWN_STATUS = -1

      private_constant :NOT_RESPONDING_SHUTDOWN_STATUS

      # @return [Array<Node>] All nodes that manager manages
      attr_reader :nodes

      def initialize
        @nodes = []
        @statuses = Hash.new { |h, k| h[k] = {} }
      end

      # Starts all the expected nodes for the first time
      def start
        parent_pid = ::Process.pid

        @nodes = Array.new(nodes_count) do |i|
          start_one Node.new(i, parent_pid)
        end
      end

      # Attempts to quiet all the nodes
      def quiet
        @nodes.each(&:quiet)
      end

      # Attempts to stop all the nodes
      def stop
        @nodes.each(&:stop)
      end

      # Terminates all the nodes
      def terminate
        @nodes.each(&:terminate)
      end

      # Collects all processes statuses
      def cleanup
        @nodes.each(&:cleanup)
      end

      # Sends given signal to all nodes
      # @param signal [String] signal name
      def signal(signal)
        @nodes.each { |node| node.signal(signal) }
      end

      # @return [Boolean] true if none of the nodes is running
      def stopped?
        @nodes.none?(&:alive?)
      end

      # Checks on nodes if they are ok one after another
      def control
        monitor.instrument('swarm.manager.control', caller: self) do
          @nodes.each do |node|
            statuses = @statuses[node]

            if node.alive?
              next if terminate_if_hanging(statuses, node)
              next if stop_if_not_healthy(statuses, node)
              next if stop_if_not_responding(statuses, node)
            else
              next if cleanup_one(statuses, node)
              next if restart_after_timeout(statuses, node)
            end
          end
        end
      end

      private

      # If we've issued a stop to this process and it does not want to stop in the period, kills it
      #
      # @param statuses [Hash] hash with statuses transitions with times
      # @param [Swarm::Node] node we're checking
      # @return [Boolean] should it be the last action taken on this node in this run
      def terminate_if_hanging(statuses, node)
        return false unless statuses.key?(:stop)
        # If we already sent the termination request, we should not do it again
        return true if statuses.key?(:terminate)
        # Do not run any other checks on this node if it is during stopping but still has time
        return true unless over?(statuses[:stop], shutdown_timeout)

        monitor.instrument('swarm.manager.terminating', caller: self, node: node) do
          node.terminate
          statuses[:terminate] = monotonic_now
        end

        true
      end

      # Checks if there is any new liveness report from given node and if yes, issues stop if it
      # reported it is not healthy.
      #
      # @param statuses [Hash] hash with statuses transitions with times
      # @param [Swarm::Node] node we're checking
      # @return [Boolean] should it be the last action taken on this node in this run
      def stop_if_not_healthy(statuses, node)
        status = node.status

        case status
        # If no new state reported, we should just move with other checks
        when -1
          false
        when 0
          # Exists and reports as healthy, so no other checks should happen on it in this go
          statuses[:control] = monotonic_now
          true
        else
          # A single invalid report will cause it to stop. We do not support intermediate failures
          # that would recover. Such states should be implemented in the listener.
          monitor.instrument('swarm.manager.stopping', caller: self, node: node, status: status) do
            node.stop
            statuses[:stop] = monotonic_now
          end

          true
        end
      end

      # If node stopped responding, starts the stopping procedure.
      #
      # @param statuses [Hash] hash with statuses transitions with times
      # @param [Swarm::Node] node we're checking
      # @return [Boolean] should it be the last action taken on this node in this run
      def stop_if_not_responding(statuses, node)
        # Do nothing if already stopping
        return true if statuses.key?(:stop)
        # Do nothing if we've received status update recently enough
        return true unless over?(statuses[:control], node_report_timeout)

        # Start the stopping procedure if the node stopped reporting frequently enough
        monitor.instrument(
          'swarm.manager.stopping',
          caller: self,
          node: node,
          status: NOT_RESPONDING_SHUTDOWN_STATUS
        ) do
          node.stop
          statuses[:stop] = monotonic_now
        end

        true
      end

      # Cleans up a dead process and remembers time of death for restart after a period.
      #
      # @param statuses [Hash] hash with statuses transitions with times
      # @param [Swarm::Node] node we're checking
      # @return [Boolean] should it be the last action taken on this node in this run
      def cleanup_one(statuses, node)
        return false if statuses.key?(:dead_since)

        node.cleanup
        statuses[:dead_since] = monotonic_now

        true
      end

      # Restarts the node if there was enough of a backoff.
      #
      # We always wait a bit to make sure, we do not overload the system in case forks would be
      # killed for some external reason.
      #
      # @param statuses [Hash] hash with statuses transitions with times
      # @param [Swarm::Node] node we're checking
      # @return [Boolean] should it be the last action taken on this node in this run
      def restart_after_timeout(statuses, node)
        return false unless over?(statuses[:dead_since], node_restart_timeout)

        start_one(node)

        true
      end

      # Starts a new node (or restarts dead)
      #
      # @param [Swarm::Node] node we're starting
      def start_one(node)
        instr_args = { caller: self, node: node }

        statuses = @statuses[node]

        statuses.clear
        statuses[:control] = monotonic_now

        monitor.instrument('swarm.manager.before_fork', instr_args)
        node.start
        monitor.instrument('swarm.manager.after_fork', instr_args)

        node
      end

      # Are we over certain time from an event happening
      #
      # @param event_time [Float] when something happened
      # @param delay [Float] how long should we wait
      # @return [Boolean] true if we're past the delay
      def over?(event_time, delay)
        monotonic_now - event_time >= delay
      end
    end
  end
end
