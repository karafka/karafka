# frozen_string_literal: true

module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single subscription group.
    # It polls the messages and then enqueues. It also takes care of potential recovery from
    # critical errors by restarting everything in a safe manner.
    class Listener
      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      # @param jobs_queue [Karafka::Processing::JobsQueue] queue where we should push work
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(subscription_group, jobs_queue)
        @subscription_group = subscription_group
        @jobs_queue = jobs_queue
        @pauses_manager = PausesManager.new
        @client = Client.new(@subscription_group)
        @executors = Processing::ExecutorsBuffer.new(@client, subscription_group)
        # We reference scheduler here as it is much faster than fetching this each time
        @scheduler = ::Karafka::App.config.internal.scheduler
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
          # We need to fetch data before we revoke lost partitions details as during the polling
          # the callbacks for tracking lost partitions are triggered. Otherwise we would be always
          # one batch behind.
          messages_buffer = @client.batch_poll

          Karafka.monitor.instrument(
            'connection.listener.fetch_loop.received',
            caller: self,
            messages_buffer: messages_buffer
          )

          # If there were revoked partitions, we need to wait on their jobs to finish before
          # distributing consuming jobs as upon revoking, we might get assigned to the same
          # partitions, thus getting their jobs. The revoking jobs need to finish before
          # appropriate consumers are taken down and re-created
          wait(@subscription_group) if schedule_revoke_lost_partitions_jobs

          schedule_partitions_jobs(messages_buffer)

          # We wait only on jobs from our subscription group. Other groups are independent.
          wait(@subscription_group)

          # We don't use the `#commit_offsets!` here for performance reasons. This can be achieved
          # if needed by using manual offset management.
          @client.commit_offsets
        end

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
        @pauses_manager.resume { |topic, partition| @client.resume(topic, partition) }
      end

      # Enqueues revoking jobs for partitions that were taken away from the running process.
      # @return [Boolean] was there anything to revoke
      # @note We do not use scheduler here as those jobs are not meant to be order optimized in
      #   any way. Since they operate occasionally it is irrelevant.
      def schedule_revoke_lost_partitions_jobs
        revoked_partitions = @client.rebalance_manager.revoked_partitions

        return false if revoked_partitions.empty?

        revoked_partitions.each do |topic, partitions|
          partitions.each do |partition|
            pause_tracker = @pauses_manager.fetch(topic, partition)
            executor = @executors.fetch(topic, partition, pause_tracker)
            @jobs_queue << Processing::Jobs::Revoked.new(executor)
          end
        end

        true
      end

      # Takes the messages per topic partition and enqueues processing jobs in threads.
      #
      # @param messages_buffer [Karafka::Connection::MessagesBuffer] buffer with messages
      def schedule_partitions_jobs(messages_buffer)
        @scheduler.call(messages_buffer) do |topic, partition, messages|
          pause = @pauses_manager.fetch(topic, partition)

          next if pause.paused?

          executor = @executors.fetch(topic, partition, pause)

          @jobs_queue << Processing::Jobs::Consume.new(executor, messages)
        end
      end

      # Waits for all the jobs from a given subscription group to finish before moving forward
      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      def wait(subscription_group)
        @jobs_queue.wait(subscription_group.id)
      end

      # Stops the jobs queue, triggers shutdown on all the executors (sync), commits offsets and
      # stops kafka client.
      def shutdown
        @jobs_queue.close
        # This runs synchronously, making sure we finish all the shutdowns before we stop the
        # client.
        @executors.shutdown
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
