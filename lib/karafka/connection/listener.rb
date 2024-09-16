# frozen_string_literal: true

module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single subscription group.
    # It polls the messages and then enqueues jobs. It also takes care of potential recovery from
    # critical errors by restarting everything in a safe manner.
    #
    # This is the heart of the consumption process.
    #
    # It provides async API for managing, so all status changes are expected to be async.
    class Listener
      include Helpers::Async

      # Can be useful for logging
      # @return [String] id of this listener
      attr_reader :id

      # @return [Karafka::Routing::SubscriptionGroup] subscription group that this listener handles
      attr_reader :subscription_group

      # How long to wait in the initial events poll. Increases chances of having the initial events
      # immediately available
      INITIAL_EVENTS_POLL_TIMEOUT = 100

      private_constant :INITIAL_EVENTS_POLL_TIMEOUT

      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      # @param jobs_queue [Karafka::Processing::JobsQueue] queue where we should push work
      # @param scheduler [Karafka::Processing::Scheduler] scheduler we want to use
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(subscription_group, jobs_queue, scheduler)
        proc_config = ::Karafka::App.config.internal.processing

        @id = SecureRandom.hex(6)
        @subscription_group = subscription_group
        @jobs_queue = jobs_queue
        @coordinators = Processing::CoordinatorsBuffer.new(subscription_group.topics)
        @client = Client.new(@subscription_group, -> { running? })
        @executors = Processing::ExecutorsBuffer.new(@client, subscription_group)
        @jobs_builder = proc_config.jobs_builder
        @partitioner = proc_config.partitioner_class.new(subscription_group)
        @scheduler = scheduler
        @events_poller = Helpers::IntervalRunner.new { @client.events_poll }
        # We keep one buffer for messages to preserve memory and not allocate extra objects
        # We can do this that way because we always first schedule jobs using messages before we
        # fetch another batch.
        @messages_buffer = MessagesBuffer.new(subscription_group)
        @mutex = Mutex.new
        @status = Status.new

        @jobs_queue.register(@subscription_group.id)

        # This makes sure that even if we tick more often than the interval time due to frequent
        # unlocks from short-lived jobs or async queues synchronization, events handling and jobs
        # scheduling still happens with the expected frequency
        @interval_runner = Helpers::IntervalRunner.new do
          @events_poller.call
          @scheduler.on_manage
        end
      end

      # Runs the main listener fetch loop.
      #
      # @note Prefetch callbacks can be used to seek offset or do other things before we actually
      #   start consuming data
      def call
        Karafka.monitor.instrument(
          'connection.listener.before_fetch_loop',
          caller: self,
          client: @client,
          subscription_group: @subscription_group
        )

        fetch_loop

        Karafka.monitor.instrument(
          'connection.listener.after_fetch_loop',
          caller: self,
          client: @client,
          subscription_group: @subscription_group
        )
      end

      # Aliases all statuses operations directly on the listener so we have a listener-facing API
      Status::STATES.each do |state, transition|
        # @return [Boolean] is the listener in a given state
        define_method "#{state}?" do
          @status.public_send("#{state}?")
        end

        # Moves listener to a given state
        define_method transition do
          @status.public_send(transition)
        end
      end

      # @return [Boolean] is this listener active (not stopped and not pending)
      def active?
        @status.active?
      end

      # We overwrite the state `#start` because on start we need to also start running listener in
      # the async thread. While other state transitions happen automatically and status state
      # change is enough, here we need to run the background threads
      def start!
        if stopped?
          @client.reset
          @status.reset!
        end

        @status.start!

        async_call("karafka.listener##{@subscription_group.id}")
      end

      # Stops the jobs queue, triggers shutdown on all the executors (sync), commits offsets and
      # stops kafka client.
      #
      # @note This method is not private despite being part of the fetch loop because in case of
      #   a forceful shutdown, it may be invoked from a separate thread
      #
      # @note We wrap it with a mutex exactly because of the above case of forceful shutdown
      def shutdown
        @mutex.synchronize do
          return if stopped?
          # Nothing to clear if it was not even running
          return stopped! if pending?

          @executors.clear
          @coordinators.reset
          @client.stop

          stopped!
        end
      end

      private

      # Fetches the data and adds it to the jobs queue.
      #
      # @note We catch all the errors here, so they don't affect other listeners (or this one)
      #   so we will be able to listen and consume other incoming messages.
      #   Since it is run inside Karafka::Connection::Runner thread - catching all the exceptions
      #   won't crash the whole process. Here we mostly focus on catching the exceptions related to
      #   Kafka connections / Internet connection issues / Etc. Business logic problems should not
      #   propagate this far.
      def fetch_loop
        running!
        # Run the initial events fetch to improve chances of having metrics and initial callbacks
        # triggers on start.
        #
        # In theory this may slow down the initial boot but we limit it up to 100ms, so it should
        # not have a big initial impact. It may not be enough but Karafka does not give the boot
        # warranties of statistics or other callbacks being immediately available, hence this is
        # a fair trade-off
        @client.events_poll(INITIAL_EVENTS_POLL_TIMEOUT)

        # Run the main loop as long as we are not stopping or moving into quiet mode
        while running?
          Karafka.monitor.instrument(
            'connection.listener.fetch_loop',
            caller: self,
            client: @client,
            subscription_group: @subscription_group
          )

          resume_paused_partitions

          Karafka.monitor.instrument(
            'connection.listener.fetch_loop.received',
            caller: self,
            client: @client,
            subscription_group: @subscription_group,
            messages_buffer: @messages_buffer
          ) do
            # We need to fetch data before we revoke lost partitions details as during the polling
            # the callbacks for tracking lost partitions are triggered. Otherwise we would be
            # always one batch behind.
            poll_and_remap_messages
          end

          # If there were revoked partitions, we need to wait on their jobs to finish before
          # distributing consuming jobs as upon revoking, we might get assigned to the same
          # partitions, thus getting their jobs. The revoking jobs need to finish before
          # appropriate consumers are taken down and re-created
          build_and_schedule_revoked_jobs_for_revoked_partitions

          # We wait only on jobs from our subscription group. Other groups are independent.
          # This will block on revoked jobs until they are finished. Those are not meant to last
          # long and should not have any bigger impact on the system. Doing this in a blocking way
          # simplifies the overall design and prevents from race conditions
          wait

          build_and_schedule_flow_jobs

          # periodic jobs never run on topics and partitions that were scheduled, so no risk in
          # having collective wait after both
          build_and_schedule_periodic_jobs if Karafka.pro?

          wait
        end

        # If we are stopping we will no longer schedule any regular jobs despite polling.
        # We need to keep polling not to exceed the `max.poll.interval` for long-running
        # non-blocking jobs and we need to allow them to finish. We however do not want to
        # enqueue any new jobs. It's worth keeping in mind that it is the end user responsibility
        # to detect shutdown in their long-running logic or else Karafka will force shutdown
        # after a while.
        #
        # We do not care about resuming any partitions or lost jobs as we do not plan to do
        # anything with them as we're in the shutdown phase.
        #
        # What we do care however is the ability to still run revocation jobs in case anything
        # would change in the cluster. We still want to notify the long-running jobs about changes
        # that occurred in the cluster.
        wait_pinging(
          wait_until: -> { @jobs_queue.empty?(@subscription_group.id) },
          after_ping: -> { build_and_schedule_revoked_jobs_for_revoked_partitions }
        )

        # We do not want to schedule the shutdown jobs prior to finishing all the jobs
        # (including non-blocking) as there might be a long-running job with a shutdown and then
        # we would run two jobs in parallel for the same executor and consumer. We do not want that
        # as it could create a race-condition.
        build_and_schedule_shutdown_jobs

        # Wait until all the shutdown jobs are done
        wait_pinging(wait_until: -> { @jobs_queue.empty?(@subscription_group.id) })

        quieted!

        # Wait if we're in the process of finishing started work or finished all the work and
        # just sitting and being quiet
        wait_pinging(wait_until: -> { !quiet? })

        # This extra ping will make sure we've refreshed the rebalance state after other instances
        # potentially shutdown. This will prevent us from closing with a dangling callback
        @client.ping

        shutdown

        # This is on purpose - see the notes for this method
        # rubocop:disable Lint/RescueException
      rescue Exception => e
        # rubocop:enable Lint/RescueException
        Karafka.monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          type: 'connection.listener.fetch_loop.error'
        )

        reset

        # Ruby sleep is in seconds
        sleep_time = ::Karafka::App.config.internal.connection.reset_backoff / 10_000.0
        sleep(sleep_time) && retry
      end

      # Resumes processing of partitions that were paused due to an error.
      def resume_paused_partitions
        @coordinators.resume do |topic, partition|
          @client.resume(topic.name, partition)
        end
      end

      # Polls messages within the time and amount boundaries defined in the settings and then
      # builds karafka messages based on the raw rdkafka messages buffer returned by the
      # `#batch_poll` method.
      #
      # @note There are two buffers, one for raw messages and one for "built" karafka messages
      def poll_and_remap_messages
        @messages_buffer.remap(
          @client.batch_poll
        )
      end

      # Enqueues revoking jobs for partitions that were taken away from the running process.
      def build_and_schedule_revoked_jobs_for_revoked_partitions
        revoked_partitions = @client.rebalance_manager.revoked_partitions

        # Stop early to save on some execution and array allocation
        return if revoked_partitions.empty?

        jobs = []

        revoked_partitions.each do |topic, partitions|
          partitions.each do |partition|
            @coordinators.revoke(topic, partition)

            # There may be a case where we have lost partition of which data we have never
            # processed (if it was assigned and revoked really fast), thus we may not have it
            # here. In cases like this, we do not run a revocation job
            @executors.find_all(topic, partition).each do |executor|
              executor.coordinator.increment(:revoked)
              jobs << @jobs_builder.revoked(executor)
            end

            # We need to remove all the executors of a given topic partition that we have lost, so
            # next time we pick up it's work, new executors kick in. This may be needed especially
            # for LRJ where we could end up with a race condition
            # This revocation needs to happen after the jobs are scheduled, otherwise they would
            # be scheduled with new executors instead of old
            @executors.revoke(topic, partition)
          end
        end

        return if jobs.empty?

        jobs.each(&:before_schedule)
        @scheduler.on_schedule_revocation(jobs)
      end

      # Enqueues the shutdown jobs for all the executors that exist in our subscription group
      def build_and_schedule_shutdown_jobs
        jobs = []

        @executors.each do |executor|
          executor.coordinator.increment(:shutdown)
          job = @jobs_builder.shutdown(executor)
          jobs << job
        end

        return if jobs.empty?

        jobs.each(&:before_schedule)
        @scheduler.on_schedule_shutdown(jobs)
      end

      # Takes the messages per topic partition and enqueues processing jobs in threads using
      # given scheduler. It also handles the idle jobs when filtering API removed all messages
      # and we need to run house-keeping
      def build_and_schedule_flow_jobs
        consume_jobs = []
        idle_jobs = []
        eofed_jobs = []

        @messages_buffer.each do |topic, partition, messages, eof, last_polled_at|
          # In case we did not receive any new messages without eof we skip.
          # We may yield empty array here in case we have reached eof without new messages but in
          # such cases, we can run an eof job
          next if messages.empty? && !eof

          coordinator = @coordinators.find_or_create(topic, partition)
          coordinator.eofed = eof
          coordinator.last_polled_at = last_polled_at

          # If we did not receive any messages and we did receive eof signal, we run the eofed
          # jobs so user can take actions on reaching eof
          if messages.empty? && eof
            # If user wants to run the eofed jobs on eof we do it. Otherwise we just allow it to
            # pass through. This allows to configure if user actually wants to have `#eofed`
            # logic or if he wants to only use fast eof work yield
            if coordinator.topic.eofed?
              @executors.find_all_or_create(topic, partition, coordinator).each do |executor|
                coordinator.increment(:eofed)
                eofed_jobs << @jobs_builder.eofed(executor)
              end
            end

            next
          end

          coordinator.start(messages)

          # If it is not an eof and there are no new messages, we just run house-keeping
          #
          # We do not increment coordinator for idle job because it's not a user related one
          # and it will not go through a standard lifecycle. Same applies to revoked and shutdown
          if messages.empty?
            # Start work coordination for this topic partition
            coordinator.increment(:idle)
            executor = @executors.find_or_create(topic, partition, 0, coordinator)
            idle_jobs << @jobs_builder.idle(executor)

            next
          end

          # If there are messages, it is irrelevant if eof or not as consumption needs to happen
          #
          # Start work coordination for this topic partition
          @partitioner.call(topic, messages, coordinator) do |group_id, partition_messages|
            coordinator.increment(:consume)
            executor = @executors.find_or_create(topic, partition, group_id, coordinator)
            consume_jobs << @jobs_builder.consume(executor, partition_messages)
          end
        end

        # We schedule the idle jobs before running the `#before_schedule` on the consume jobs so
        # workers can already pick up the idle jobs while the `#before_schedule` on consumption
        # jobs runs
        unless idle_jobs.empty?
          idle_jobs.each(&:before_schedule)
          @scheduler.on_schedule_idle(idle_jobs)
        end

        unless consume_jobs.empty?
          consume_jobs.each(&:before_schedule)
          @scheduler.on_schedule_consumption(consume_jobs)
        end

        unless eofed_jobs.empty?
          eofed_jobs.each(&:before_schedule)
          @scheduler.on_schedule_eofed(eofed_jobs)
        end
      end

      # Builds and schedules periodic jobs for topics partitions for which no messages were
      # received recently. In case `Idle` job is invoked, we do not run periodic. Idle means that
      # a complex flow kicked in and it was a user choice not to run consumption but messages were
      # shipped.
      def build_and_schedule_periodic_jobs
        # Shortcut if periodic jobs are not used at all. No need to run the complex flow when it
        # will never end up with anything. If periodics on any of the topics are not even defined,
        # we can finish fast
        @periodic_jobs ||= @subscription_group.topics.count(&:periodic_job?)

        return if @periodic_jobs.zero?

        jobs = []

        # We select only currently assigned topics and partitions from the current subscription
        # group as only those are of our interest. We then filter that to only pick those for whom
        # we want to run periodic jobs and then we select only those that did not receive any
        # messages recently. This ensures, that we do not tick close to recent arrival of messages
        # but rather after certain period of inactivity
        Karafka::App.assignments.each do |topic, partitions|
          # Skip for assignments not from our subscription group
          next unless topic.subscription_group == @subscription_group
          # Skip if this topic does not have periodic jobs enabled
          next unless topic.periodic_job?

          topic_name = topic.name
          interval = topic.periodic_job.interval

          partitions.each do |partition|
            coordinator = @coordinators.find_or_create(topic_name, partition)

            # Skip if we were operating on a given topic partition recently
            next if coordinator.active_within?(interval)

            # Do not tick if we do not want to tick during pauses
            next if coordinator.paused? && !topic.periodic_job.during_pause?

            # If we do not want to run periodics during retry flows, we should not
            # Since this counter is incremented before processing, here it is always -1 from what
            # we see in the consumer flow. This is why attempt 0 means that we will have first
            # run (ok) but attempt 1 means, there was an error and we will retry
            next if coordinator.attempt.positive? && !topic.periodic_job.during_retry?

            @executors.find_all_or_create(topic_name, partition, coordinator).each do |executor|
              coordinator.increment(:periodic)
              jobs << @jobs_builder.periodic(executor)
            end
          end
        end

        return if jobs.empty?

        jobs.each(&:before_schedule)
        @scheduler.on_schedule_periodic(jobs)
      end

      # Waits for all the jobs from a given subscription group to finish before moving forward
      def wait
        @jobs_queue.wait(@subscription_group.id) do
          @interval_runner.call
        end
      end

      # Waits without blocking the polling
      #
      # This should be used only when we no longer plan to use any incoming messages data and we
      # can safely discard it. We can however use the rebalance information if needed.
      #
      # @param wait_until [Proc] until this evaluates to true, we will poll data
      # @param after_ping [Proc] code that we want to run after each ping (if any)
      #
      # @note Performance of this is not relevant (in regards to blocks) because it is used only
      #   on shutdown and quiet, hence not in the running mode
      def wait_pinging(wait_until:, after_ping: -> {})
        until wait_until.call
          @client.ping
          @scheduler.on_manage

          after_ping.call
          sleep(0.2)
        end
      end

      # We can stop client without a problem, as it will reinitialize itself when running the
      # `#fetch_loop` again. We just need to remember to also reset the runner as it is a long
      # running one, so with a new connection to Kafka, we need to initialize the state of the
      # runner and underlying consumers once again.
      def reset
        # If there was any problem with processing, before we reset things we need to make sure,
        # there are no jobs in the queue. Otherwise it could lead to leakage in between client
        # resetting.
        @jobs_queue.wait(@subscription_group.id)
        @jobs_queue.clear(@subscription_group.id)
        @scheduler.on_clear(@subscription_group.id)
        @events_poller.reset
        @client.reset
        @coordinators.reset
        @interval_runner.reset
        @executors = Processing::ExecutorsBuffer.new(@client, @subscription_group)
      end
    end
  end
end
