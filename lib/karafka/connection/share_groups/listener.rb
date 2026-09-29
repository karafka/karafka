# frozen_string_literal: true

module Karafka
  module Connection
    module ShareGroups
      # A single listener that consumes from one share-group subscription group.
      #
      # It follows the KIP-932 tight-loop model: poll a batch of already-acquired records, process
      # them inline (the listener thread is the worker - `workers_per_consumer` defaults to 1),
      # acknowledge per record and flush, then poll again. There is no shared jobs queue, no
      # partition pausing/seeking and no rebalance handling - share assignment is fully
      # broker-driven and records are redelivered by the broker if their acquisition lock expires
      # unacknowledged.
      #
      # It provides an async API for managing, so all status changes are expected to be async.
      class Listener
        include Helpers::Async

        include Helpers::ConfigImporter.new(
          reset_backoff: %i[internal connection reset_backoff],
          listener_thread_priority: %i[internal connection listener_thread_priority]
        )

        # @return [String] id of this listener
        attr_reader :id

        # @return [Karafka::Routing::SubscriptionGroup] subscription group that this listener
        #   handles
        attr_reader :subscription_group

        # @param subscription_group [Karafka::Routing::SubscriptionGroup]
        # @param jobs_queue [Object, nil] accepted for a uniform listener API with consumer groups;
        #   share groups process inline and do not use a shared jobs queue
        # @param scheduler [Object, nil] accepted for a uniform listener API; unused by share groups
        def initialize(subscription_group, jobs_queue = nil, scheduler = nil)
          @id = SecureRandom.hex(6)
          @subscription_group = subscription_group
          @jobs_queue = jobs_queue
          @scheduler = scheduler
          @client = Client.new(@subscription_group)
          # One executor + coordinator per topic. A share poll batch may span topics; each topic's
          # records are consumed as one batch by that topic's consumer instance.
          @executors = {}
          @coordinators = {}
          @mutex = Mutex.new
          @status = Status.new
        end

        # Runs the main listener consume loop.
        def call
          Karafka.monitor.instrument(
            "connection.listener.before_fetch_loop",
            caller: self,
            client: @client,
            subscription_group: @subscription_group
          )

          fetch_loop

          Karafka.monitor.instrument(
            "connection.listener.after_fetch_loop",
            caller: self,
            client: @client,
            subscription_group: @subscription_group
          )
        end

        # Aliases all status operations on the listener so we have a listener-facing API
        Status::STATES.each do |state, transition|
          # @return [Boolean] is the listener in a given state
          define_method "#{state}?" do
            @status.public_send("#{state}?")
          end

          next if transition == :start!

          # Moves listener to a given state
          define_method transition do
            @status.public_send(transition)
          end
        end

        # @return [Boolean] is this listener active (not stopped and not pending)
        def active?
          @status.active?
        end

        # Starts the listener in its own async thread.
        def start!
          if stopped?
            @client.reset
            @status.reset!
          end

          @status.start!

          async_call(
            "karafka.share_listener##{@subscription_group.id}",
            listener_thread_priority
          )
        end

        # Triggers shutdown on all the executors (sync) and stops the kafka client.
        #
        # @note Not private despite being part of the fetch loop because on a forceful shutdown it
        #   may be invoked from a separate thread, hence the mutex.
        def shutdown
          @mutex.synchronize do
            return if stopped?
            return stopped! if pending?

            @executors.each_value(&:shutdown)
            @executors.clear
            @coordinators.clear
            @client.stop

            stopped!
          end
        end

        private

        # The tight poll-process-acknowledge loop with error recovery.
        #
        # @note We catch all the errors here so they don't affect other listeners. Since this runs
        #   inside the runner thread, catching everything won't crash the process.
        def fetch_loop
          running!

          while running?
            Karafka.monitor.instrument(
              "connection.listener.fetch_loop",
              caller: self,
              client: @client,
              subscription_group: @subscription_group
            )

            fetch_and_consume
          end

          # We are quieting or stopping now. Move to quiet and hold until we are told to fully stop.
          quieted!

          sleep(0.1) while quiet?

          shutdown

          # This is on purpose - see the consumer-group listener for the rationale
          # rubocop:disable Lint/RescueException
        rescue Exception => e
          # rubocop:enable Lint/RescueException
          Karafka.monitor.instrument(
            "error.occurred",
            caller: self,
            error: e,
            type: "connection.listener.fetch_loop.error"
          )

          reset

          sleep(reset_backoff / 1_000.0) && retry
        end

        # Polls a single batch and consumes it inline, grouped per topic.
        #
        # @note We intentionally do not emit `connection.listener.fetch_loop.received` here. That
        #   event carries a consumer-group `MessagesBuffer` (with a partition/eof-aware `#each` and
        #   `#size`) that several shared subscribers depend on; a share poll returns a flat batch
        #   with different semantics. A share-specific received event can be added later once its
        #   payload shape is settled.
        def fetch_and_consume
          messages = @client.batch_poll

          return if messages.empty?

          messages.group_by(&:topic).each do |topic_name, topic_messages|
            consume_topic_batch(topic_name, topic_messages)
          end
        end

        # Builds Karafka messages for one topic's slice of the poll batch and runs the consumer
        # inline through its full flow.
        #
        # @param topic_name [String] name of the topic these raw messages belong to
        # @param raw_messages [Array<Rdkafka::ShareConsumer::Message>] raw records for that topic
        def consume_topic_batch(topic_name, raw_messages)
          topic = @subscription_group.topics.find(topic_name)

          # A record for a topic we are not routing (should not happen given our subscription) is
          # skipped; leaving it unacknowledged lets the broker redeliver/expire it.
          return unless topic

          received_at = Time.now

          built = raw_messages.map do |raw_message|
            Messages::Builders::Message.call(raw_message, topic, received_at)
          end

          coordinator = coordinator_for(topic)
          executor = executor_for(topic, coordinator)

          coordinator.start(built)
          coordinator.increment(:consume)

          executor.before_schedule_consume(built)
          executor.before_consume
          executor.consume
          executor.after_consume
        end

        # @param topic [Karafka::Routing::Topic]
        # @return [Karafka::Processing::ShareGroups::Coordinator]
        def coordinator_for(topic)
          @coordinators[topic.name] ||= Processing::ShareGroups::Coordinator.new(topic)
        end

        # @param topic [Karafka::Routing::Topic]
        # @param coordinator [Karafka::Processing::ShareGroups::Coordinator]
        # @return [Karafka::Processing::ShareGroups::Executor]
        def executor_for(topic, coordinator)
          @executors[topic.name] ||= Processing::ShareGroups::Executor.new(
            @subscription_group.id,
            @client,
            coordinator
          )
        end

        # Closes and resets the client and per-topic caches so the loop can restart cleanly after
        # an error.
        def reset
          @client.reset
          @executors.clear
          @coordinators.clear
        end
      end
    end
  end
end
