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

        monitor.instrument('app.before_warmup', caller: self)

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
          .map { |cg| [cg, cg.subscription_groups] }
          .select { |cg, _| cg.active? }
          .select { |_, sgs| sgs.delete_if { |sg| !sg.active? } }
          .delete_if { |_, sgs| sgs.empty? }
          .each { |_, sgs| sgs.each { |sg| sg.topics.delete_if { |top| !top.active? } } }
          .each { |_, sgs| sgs.delete_if { |sg| sg.topics.empty? } }
          .reject { |cg, _| cg.subscription_groups.empty? }
          .to_h
      end

      # Just a nicer name for the consumer groups
      alias routes consumer_groups

      # Returns current assignments of this process. Both topics and partitions
      #
      # @return [Hash<Karafka::Routing::Topic, Array<Integer>>]
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
      def debug!(contexts = 'all')
        logger.level = ::Logger::DEBUG
        producer.config.logger.level = ::Logger::DEBUG

        config.kafka[:debug] = contexts
        producer.config.kafka[:debug] = contexts

        consumer_groups.map(&:topics).flat_map(&:to_a).each do |topic|
          topic.kafka[:debug] = contexts
        end
      end
    end
  end
end
