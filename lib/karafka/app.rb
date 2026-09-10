# frozen_string_literal: true

module Karafka
  # App class
  class App
    extend Setup::Dsl

    class << self
      # Notifies the Ruby virtual machine that the boot sequence is finished, and that now is a
      # good time to optimize the application. In case of older Ruby versions, runs compacting,
      # which is part of the full warmup introduced in Ruby 3.3.
      def warmup
        # Per recommendation, this should not run in children nodes
        return if Karafka::App.config.swarm.node

        monitor.instrument("app.before_warmup", caller: self)

        return GC.compact unless ::Process.respond_to?(:warmup)

        ::Process.warmup
      end

      # @return [Karafka::Routing::Builder] consumers builder instance alias
      def consumer_groups
        config
          .internal
          .routing
          .builder
      end

      # @return [Hash] active subscription groups grouped based on consumer group in a hash
      def subscription_groups
        # We first build all the subscription groups, so they all get the same position, despite
        # later narrowing that. It allows us to maintain same position number for static members
        # even when we want to run subset of consumer groups or subscription groups
        #
        # We then narrow this to active consumer groups from which we select active subscription
        # groups.
        consumer_groups
          .map { |group| [group, group.subscription_groups] }
          .select { |group, _| group.active? }
          .select { |_, sgs| sgs.delete_if { |sg| !sg.active? } }
          .delete_if { |_, sgs| sgs.empty? }
          .each { |_, sgs| sgs.each { |sg| sg.topics.delete_if { |topic| !topic.active? } } }
          .each { |_, sgs| sgs.delete_if { |sg| sg.topics.empty? } }
          .reject { |group, _| group.subscription_groups.empty? }
          .to_h
      end

      # @return [Karafka::Declaratives::Builder] declaratives builder instance
      def declaratives
        config
          .internal
          .declaratives
          .builder
      end

      # Just a nicer name for the consumer groups
      alias_method :routes, :consumer_groups
      # Generalized alias - routing entries are "groups" (consumer groups and, since KIP-932,
      # share groups). Returns every group regardless of its type.
      alias_method :groups, :consumer_groups

      # @return [Array<Karafka::Routing::ShareGroups::Group>] all defined share groups (KIP-932).
      # @note Share groups live in the same routing builder as consumer groups; this is just a
      #   type-filtered view. Empty unless `share_group` routing blocks are defined.
      def share_groups
        groups.select(&:share_group?)
      end

      # Ensures no active share group is about to be run. Share groups (KIP-932) can be described
      # in the routing but their runtime is not implemented yet, so every run seam (listeners
      # assembly, swarm supervisor pre-fork) refuses to proceed instead of silently doing nothing.
      # Excluding them (e.g. `--exclude_share_groups`) or not defining them lets the rest of the
      # app run.
      #
      # @raise [Karafka::Errors::ShareGroupsNotImplementedError] when an active share group is
      #   present in the routing
      def verify_share_groups_inactive!
        subscription_groups.each_key do |group|
          next unless group.share_group?

          raise(
            Errors::ShareGroupsNotImplementedError,
            "Share group '#{group.name}' cannot be run yet - share group (KIP-932) runtime " \
            "support is not implemented. See the KIP-932 roadmap for progress."
          )
        end
      end

      # Returns current assignments of this process. Both topics and partitions
      #
      # @return [Hash{Karafka::Routing::Topic => Array<Integer>}]
      def assignments
        Instrumentation::AssignmentsTracker.instance.current
      end

      # Allow for easier status management via `Karafka::App` by aliasing status methods here
      Status::STATES.each do |state, transition|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{state}
            App.config.internal.status.#{state}
          end

          def #{state}?
            App.config.internal.status.#{state}?
          end

          def #{transition}
            App.config.internal.status.#{transition}
          end
        RUBY
      end

      # @return [Boolean] true if we should be done in general with processing anything
      # @note It is a meta status from the status object
      def done?
        App.config.internal.status.done?
      end

      # Methods that should be delegated to Karafka module
      %i[
        root
        env
        logger
        producer
        monitor
        pro?
      ].each do |delegated|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{delegated}
            Karafka.#{delegated}
          end
        RUBY
      end

      # Forces the debug setup onto Karafka and default WaterDrop producer.
      # This needs to run prior to any operations that would cache state, like consuming or
      # producing messages.
      #
      # @param contexts [String] librdkafka low level debug contexts for granular debugging
      def debug!(contexts = "all")
        logger.level = Logger::DEBUG
        producer.config.logger.level = Logger::DEBUG

        config.kafka[:debug] = contexts
        producer.config.kafka[:debug] = contexts

        routes.map(&:topics).flat_map(&:to_a).each do |topic|
          topic.kafka[:debug] = contexts
        end
      end
    end
  end
end
