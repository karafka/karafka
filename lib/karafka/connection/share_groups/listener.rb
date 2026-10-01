# frozen_string_literal: true

module Karafka
  module Connection
    module ShareGroups
      # A single listener that consumes from one share-group subscription group.
      #
      # It follows the KIP-932 model: poll a batch of already-acquired records, schedule the
      # consumption on the shared workers pool (the same pool consumer groups use) and wait for it
      # to finish before polling again, then acknowledge per record and flush. There is no
      # partition pausing/seeking and no rebalance handling - share assignment is fully
      # broker-driven and records are redelivered by the broker if their acquisition lock expires
      # unacknowledged.
      #
      # It provides an async API for managing, so all status changes are expected to be async.
      class Listener
        include Helpers::Async

        include Helpers::ConfigImporter.new(
          jobs_builder: %i[internal processing share_groups jobs_builder],
          partitioner_class: %i[internal processing share_groups partitioner_class],
          reset_backoff: %i[internal connection reset_backoff],
          listener_thread_priority: %i[internal connection listener_thread_priority]
        )

        # @return [String] id of this listener
        attr_reader :id

        # @return [Karafka::Routing::SubscriptionGroup] subscription group that this listener
        #   handles
        attr_reader :subscription_group

        # How long to wait in the initial events poll. Increases chances of having the initial
        # events (statistics, callbacks) immediately available.
        INITIAL_EVENTS_POLL_TIMEOUT = 100

        private_constant :INITIAL_EVENTS_POLL_TIMEOUT

        # @param subscription_group [Karafka::Routing::SubscriptionGroup]
        # @param jobs_queue [Karafka::Processing::ConsumerGroups::JobsQueue] queue where we push
        #   work (shared with consumer groups)
        # @param scheduler [Karafka::Processing::Schedulers::Default] scheduler we use to dispatch
        #   jobs onto the workers pool
        def initialize(subscription_group, jobs_queue, scheduler)
          @id = SecureRandom.hex(6)
          @subscription_group = subscription_group
          @jobs_queue = jobs_queue
          @scheduler = scheduler
          @client = Client.new(@subscription_group)
          # Like for consumer groups, records are coordinated and consumed per topic partition (and
          # further per partitioner group), so the records of a poll batch spanning many
          # partitions are processed in parallel.
          @coordinators = Processing::ShareGroups::CoordinatorsBuffer.new(subscription_group.topics)
          @executors = Processing::ShareGroups::ExecutorsBuffer.new(@client, subscription_group)
          @partitioner = partitioner_class.new(subscription_group)
          # Services the rdkafka main queue (statistics, error, OAuth callbacks) without acquiring
          # share records, so callbacks keep flowing even while we are not polling for records.
          @events_poller = Helpers::IntervalRunner.new { |**opts| @client.events_poll(**opts) }
          @mutex = Mutex.new
          @status = Status.new

          @jobs_queue.register(@subscription_group.id)

          # Throttles events servicing (and any scheduler management) so it happens with the
          # expected frequency even when jobs unlock the wait more often than the tick interval.
          @interval_runner = Helpers::IntervalRunner.new do
            @events_poller.call
            @scheduler.on_manage
          end
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

        # Triggers shutdown and stops the kafka client.
        #
        # @note Not private despite being part of the fetch loop because on a forceful shutdown it
        #   may be invoked from a separate thread, hence the mutex.
        def shutdown
          @mutex.synchronize do
            return if stopped?
            return stopped! if pending?

            @executors.clear
            @coordinators.reset
            @client.stop

            stopped!
          end
        end

        private

        # The poll-schedule-wait loop with error recovery.
        #
        # @note We catch all the errors here so they don't affect other listeners. Since this runs
        #   inside the runner thread, catching everything won't crash the process.
        def fetch_loop
          running!

          # Run the initial events poll to improve chances of having statistics and initial
          # callbacks available on start. Bounded so it does not delay boot noticeably.
          @client.events_poll(INITIAL_EVENTS_POLL_TIMEOUT)

          while running?
            Karafka.monitor.instrument(
              "connection.listener.fetch_loop",
              caller: self,
              client: @client,
              subscription_group: @subscription_group
            )

            consumed = poll_and_schedule

            wait

            flush_acknowledgements if consumed
          end

          # We are quieting or stopping now. Drain any in-flight consume jobs before running the
          # shutdown jobs, servicing events so callbacks keep flowing while we wait.
          wait_servicing_events(wait_until: -> { @jobs_queue.empty?(@subscription_group.id) })

          build_and_schedule_shutdown_jobs

          wait_servicing_events(wait_until: -> { @jobs_queue.empty?(@subscription_group.id) })

          quieted!

          wait_servicing_events(wait_until: -> { !quiet? })

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

        # Polls a single batch and schedules it on the workers pool: consume jobs when records were
        # returned, idle jobs (housekeeping) when the poll came back empty.
        #
        # @note We intentionally do not emit `connection.listener.fetch_loop.received` here. That
        #   event carries a consumer-group `MessagesBuffer` (with a partition/eof-aware `#each` and
        #   `#size`) that several shared subscribers depend on; a share poll returns a flat batch
        #   with different semantics. A share-specific received event can be added later once its
        #   payload shape is settled.
        #
        # @return [Boolean] were any records polled
        def poll_and_schedule
          messages = @client.batch_poll

          if messages.empty?
            build_and_schedule_idle_jobs

            false
          else
            build_and_schedule_consume_jobs(messages)

            true
          end
        end

        # Runs once the whole polled batch was processed. Releases any record that is still not
        # acknowledged (the processing strategies settle every record, so this only happens when
        # something went wrong outside of the consumption flow) - otherwise the next poll would be
        # refused. Then flushes the acknowledgements of the batch to the broker.
        def flush_acknowledgements
          released = @client.release_pending

          if released.positive?
            Karafka.monitor.instrument(
              "error.occurred",
              caller: self,
              error: Errors::UnacknowledgedRecordsError.new(
                "#{released} records were released without being acknowledged"
              ),
              type: "connection.client.unacknowledged.error"
            )
          end

          @client.commit
        end

        # Builds consume jobs for a non-empty poll batch and schedules them on the workers pool.
        # Like for consumer groups, records are grouped per topic partition and each group can be
        # further divided by the partitioner, every resulting group being one consume job.
        #
        # @param messages [Array<Rdkafka::ShareConsumer::Message>] raw records from the poll
        def build_and_schedule_consume_jobs(messages)
          received_at = Time.now
          jobs = []

          messages.group_by { |message| [message.topic, message.partition] }.each do |key, raws|
            topic_name, partition = key
            topic = @subscription_group.topics.find(topic_name)

            # A record for a topic we are not routing (should not happen given our subscription) is
            # skipped; it stays unacknowledged and is released after the batch for redelivery.
            next unless topic

            built = raws.map do |raw_message|
              message = Messages::Builders::Message.call(raw_message, topic, received_at)
              message.metadata.delivery_count = raw_message.delivery_count
              message
            end

            coordinator = @coordinators.find_or_create(topic_name, partition)
            coordinator.start(built)

            @partitioner.call(topic_name, built, coordinator) do |group_id, partition_messages|
              coordinator.increment(:consume)
              executor = @executors.find_or_create(topic_name, partition, group_id, coordinator)
              jobs << jobs_builder.consume(executor, partition_messages)
            end
          end

          return if jobs.empty?

          jobs.each(&:before_schedule)
          @scheduler.on_schedule_consumption(jobs)
        end

        # Enqueues idle (housekeeping) jobs for the active consumers when a poll returned no
        # records, so periodic work can run even without new messages. We only run idle for topics
        # that already have an executor (i.e. that have consumed at least once) - there is no share
        # assignment API to enumerate, so we do not spin up consumers for topics that never ran.
        #
        # @note Idle jobs are tracked by the jobs queue itself (like shutdown jobs), so they are not
        #   counted on the coordinator.
        def build_and_schedule_idle_jobs
          jobs = []

          @executors.each do |executor|
            jobs << jobs_builder.idle(executor)
          end

          return if jobs.empty?

          jobs.each(&:before_schedule)
          @scheduler.on_schedule_idle(jobs)
        end

        # Enqueues the shutdown jobs for all the executors that exist in our subscription group.
        def build_and_schedule_shutdown_jobs
          jobs = []

          @executors.each do |executor|
            jobs << jobs_builder.shutdown(executor)
          end

          return if jobs.empty?

          jobs.each(&:before_schedule)
          @scheduler.on_schedule_shutdown(jobs)
        end

        # Waits for all the jobs from our subscription group to finish before moving forward,
        # servicing the rdkafka events queue while blocked so callbacks keep flowing.
        def wait
          @jobs_queue.wait(@subscription_group.id) do
            @interval_runner.call
          end
        end

        # Waits until the given condition is met, servicing the events queue on each tick so
        # statistics and callbacks keep flowing during the shutdown and quiet phases (where we no
        # longer poll for records). Errors here are swallowed - on the way down they are not
        # relevant enough to trigger a full listener reset.
        #
        # @param wait_until [Proc] until this evaluates to true, we keep servicing events
        def wait_servicing_events(wait_until:)
          until wait_until.call
            @events_poller.call(safe: true)
            sleep(0.2)
          end
        end

        # Closes and resets the client, per-topic caches and the jobs queue state so the loop can
        # restart cleanly after an error.
        def reset
          # Make sure there are no in-flight jobs before resetting, otherwise a job could reference
          # a client we are about to close.
          @jobs_queue.wait(@subscription_group.id)
          @jobs_queue.clear(@subscription_group.id)
          @scheduler.on_clear(@subscription_group.id)
          @events_poller.reset
          @interval_runner.reset
          @client.reset
          @coordinators.reset
          @executors.clear
        end
      end
    end
  end
end
