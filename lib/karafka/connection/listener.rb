# frozen_string_literal: true

module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single subscription group.
    # It polls the messages and then enqueues jobs. It also takes care of potential recovery from
    # critical errors by restarting everything in a safe manner.
    #
    # This is the heart of the consumption process.
    class Listener
      include Helpers::Async

      # Can be useful for logging
      # @return [String] id of this listener
      attr_reader :id

      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      # @param jobs_queue [Karafka::Processing::JobsQueue] queue where we should push work
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(subscription_group, jobs_queue)
        @id = SecureRandom.uuid
        @subscription_group = subscription_group
        @jobs_queue = jobs_queue
        @jobs_builder = ::Karafka::App.config.internal.jobs_builder
        @pauses_manager = PausesManager.new
        @client = Client.new(@subscription_group)
        @executors = Processing::ExecutorsBuffer.new(@client, subscription_group)
        # We reference scheduler here as it is much faster than fetching this each time
        @scheduler = ::Karafka::App.config.internal.scheduler
        # We keep one buffer for messages to preserve memory and not allocate extra objects
        # We can do this that way because we always first schedule jobs using messages before we
        # fetch another batch.
        @messages_buffer = MessagesBuffer.new(subscription_group)
      end

      # Runs the main listener fetch loop.
      #
      # @note Prefetch callbacks can be used to seek offset or do other things before we actually
      #   start consuming data
      def call
        Karafka.monitor.instrument(
          'connection.listener.before_fetch_loop',
          caller: self,
          subscription_group: @subscription_group,
          client: @client
        )

        fetch_loop
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
        until Karafka::App.stopping?
          Karafka.monitor.instrument(
            'connection.listener.fetch_loop',
            caller: self,
            client: @client
          )

          resume_paused_partitions

          Karafka.monitor.instrument(
            'connection.listener.fetch_loop.received',
            caller: self,
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
          build_and_schedule_revoke_lost_partitions_jobs

          # We wait only on jobs from our subscription group. Other groups are independent.
          wait

          build_and_schedule_consumption_jobs

          wait

          # We don't use the `#commit_offsets!` here for performance reasons. This can be achieved
          # if needed by using manual offset management.
          @client.commit_offsets
        end

        # If we are stopping we will no longer schedule any jobs despite polling.
        # We need to keep polling not to exceed the `max.poll.interval` for long-running
        # non-blocking jobs and we need to allow them to finish. We however do not want to
        # enqueue any new jobs. It's worth keeping in mind that it is the end user responsibility
        # to detect shutdown in their long-running logic or else Karafka will force shutdown
        # after a while.
        #
        # We do not care about resuming any partitions or lost jobs as we do not plan to do
        # anything with them as we're in the shutdown phase.
        wait_with_poll

        # We do not want to schedule the shutdown jobs prior to finishing all the jobs
        # (including non-blocking) as there might be a long-running job with a shutdown and then
        # we would run two jobs in parallel for the same executor and consumer. We do not want that
        # as it could create a race-condition.
        build_and_schedule_shutdown_jobs

        wait_with_poll

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

        restart

        sleep(1) && retry
      end

      # Resumes processing of partitions that were paused due to an error.
      def resume_paused_partitions
        @pauses_manager.resume do |topic, partition|
          @client.resume(topic, partition)
        end
      end

      # Enqueues revoking jobs for partitions that were taken away from the running process.
      def build_and_schedule_revoke_lost_partitions_jobs
        revoked_partitions = @client.rebalance_manager.revoked_partitions

        # Stop early to save on some execution and array allocation
        return if revoked_partitions.empty?

        jobs = []

        revoked_partitions.each do |topic, partitions|
          partitions.each do |partition|
            pause_tracker = @pauses_manager.fetch(topic, partition)
            executor = @executors.fetch(topic, partition, pause_tracker)
            jobs << @jobs_builder.revoked(executor)
          end
        end

        @scheduler.schedule_revocation(@jobs_queue, jobs)
      end

      # Enqueues the shutdown jobs for all the executors that exist in our subscription group
      def build_and_schedule_shutdown_jobs
        jobs = []

        @executors.each do |_, _, executor|
          jobs << @jobs_builder.shutdown(executor)
        end

        @scheduler.schedule_shutdown(@jobs_queue, jobs)
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

      # Takes the messages per topic partition and enqueues processing jobs in threads using
      # given scheduler.
      def build_and_schedule_consumption_jobs
        return if @messages_buffer.empty?

        jobs = []

        @messages_buffer.each do |topic, partition, messages|
          pause_tracker = @pauses_manager.fetch(topic, partition)

          executor = @executors.fetch(topic, partition, pause_tracker)

          jobs << @jobs_builder.consume(executor, messages)
        end

        @scheduler.schedule_consumption(@jobs_queue, jobs)
      end

      # Waits for all the jobs from a given subscription group to finish before moving forward
      def wait
        @jobs_queue.wait(@subscription_group.id)
      end

      # Waits without blocking the polling
      # This should be used only when we no longer plan to use any incoming data and we can safely
      # discard it
      def wait_with_poll
        @client.batch_poll until @jobs_queue.empty?(@subscription_group.id)
      end

      # Stops the jobs queue, triggers shutdown on all the executors (sync), commits offsets and
      # stops kafka client.
      def shutdown
        @client.commit_offsets!
        @client.stop
      end

      # We can stop client without a problem, as it will reinitialize itself when running the
      # `#fetch_loop` again. We just need to remember to also reset the runner as it is a long
      # running one, so with a new connection to Kafka, we need to initialize the state of the
      # runner and underlying consumers once again.
      def restart
        # If there was any problem with processing, before we reset things we need to make sure,
        # there are no jobs in the queue. Otherwise it could lead to leakage in between client
        # resetting.
        @jobs_queue.wait(@subscription_group.id)
        @jobs_queue.clear(@subscription_group.id)
        @client.reset
        @pauses_manager = PausesManager.new
        @executors = Processing::ExecutorsBuffer.new(@client, @subscription_group)
      end
    end
  end
end
