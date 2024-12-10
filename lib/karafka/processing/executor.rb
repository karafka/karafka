# frozen_string_literal: true

module Karafka
  # Namespace that encapsulates all the logic related to processing data.
  module Processing
    # Executors:
    # - run consumers code (for `#call`) or run given preparation / teardown operations when needed
    #   from separate threads.
    # - they re-create consumer instances in case of partitions that were revoked and assigned
    #   back.
    #
    # @note Executors are not removed after partition is revoked. They are not that big and will
    #   be re-used in case of a re-claim
    #
    # @note Since given consumer can run various operations, executor manages that and its
    #   lifecycle. There are following types of operations with appropriate before/after, etc:
    #
    #   - consume - primary operation related to running user consumption code
    #   - idle - cleanup job that runs on idle runs where no messages would be passed to the end
    #     user. This is used for complex flows with filters, etc
    #   - revoked - runs after the partition was revoked
    #   - shutdown - runs when process is going to shutdown
    class Executor
      extend Forwardable
      include Helpers::ConfigImporter.new(
        strategy_selector: %i[internal processing strategy_selector],
        expansions_selector: %i[internal processing expansions_selector]
      )

      def_delegators :@coordinator, :topic, :partition

      # @return [String] unique id that we use to ensure, that we use for state tracking
      attr_reader :id

      # @return [String] subscription group id to which a given executor belongs
      attr_reader :group_id

      # @return [Karafka::Messages::Messages] messages batch
      attr_reader :messages

      # @return [Karafka::Processing::Coordinator] coordinator for this executor
      attr_reader :coordinator

      # @param group_id [String] id of the subscription group to which the executor belongs
      # @param client [Karafka::Connection::Client] kafka client
      # @param coordinator [Karafka::Processing::Coordinator]
      def initialize(group_id, client, coordinator)
        @id = SecureRandom.hex(6)
        @group_id = group_id
        @client = client
        @coordinator = coordinator
      end

      # Allows us to prepare the consumer in the listener thread prior to the job being send to
      # be scheduled. It also allows to run some code that is time sensitive and cannot wait in the
      # queue as it could cause starvation.
      #
      # @param messages [Array<Karafka::Messages::Message>]
      def before_schedule_consume(messages)
        # Recreate consumer with each batch if persistence is not enabled
        # We reload the consumers with each batch instead of relying on some external signals
        # when needed for consistency. That way devs may have it on or off and not in this
        # middle state, where re-creation of a consumer instance would occur only sometimes
        @consumer = nil unless topic.consumer_persistence

        # First we build messages batch...
        consumer.messages = Messages::Builders::Messages.call(
          messages,
          topic,
          partition,
          # the moment we've received the batch or actually the moment we've enqueued it,
          # but good enough
          Time.now
        )

        consumer.on_before_schedule_consume
      end

      # Runs setup and warm-up code in the worker prior to running the consumption
      def before_consume
        consumer.on_before_consume
      end

      # Runs the wrap/around execution context appropriate for a given action
      # @param action [Symbol] action execution wrapped with our block
      # @param block [Proc] execution context
      def wrap(action, &block)
        consumer.on_wrap(action, &block)
      end

      # Runs consumer data processing against given batch and handles failures and errors.
      def consume
        # We run the consumer client logic...
        consumer.on_consume
      end

      # Runs consumer after consumption code
      def after_consume
        consumer.on_after_consume
      end

      # Runs the code needed before idle work is scheduled
      def before_schedule_idle
        consumer.on_before_schedule_idle
      end

      # Runs consumer idle operations
      # This may include house-keeping or other state management changes that can occur but that
      # not mean there are any new messages available for the end user to process
      def idle
        consumer.on_idle
      end

      # Runs the code needed before eofed work is scheduled
      def before_schedule_eofed
        consumer.on_before_schedule_eofed
      end

      # Runs consumed eofed operation.
      # This may run even when there were no messages received prior. This will however not
      # run when eof is received together with messages as in such case `#consume` will run
      def eofed
        consumer.on_eofed
      end

      # Runs code needed before revoked job is scheduled
      def before_schedule_revoked
        consumer.on_before_schedule_revoked if @consumer
      end

      # Runs the controller `#revoked` method that should be triggered when a given consumer is
      # no longer needed due to partitions reassignment.
      #
      # @note Clearing the consumer will ensure, that if we get the partition back, it will be
      #   handled with a consumer with a clean state.
      #
      # @note We run it only when consumer was present, because presence indicates, that at least
      #   a single message has been consumed.
      #
      # @note We do not reset the consumer but we indicate need for recreation instead, because
      #   after the revocation, there still may be `#after_consume` running that needs a given
      #   consumer instance.
      def revoked
        consumer.on_revoked if @consumer
      end

      # Runs code needed before shutdown job is scheduled
      def before_schedule_shutdown
        consumer.on_before_schedule_shutdown if @consumer
      end

      # Runs the controller `#shutdown` method that should be triggered when a given consumer is
      # no longer needed as we're closing the process.
      #
      # @note While we do not need to clear the consumer here, it's a good habit to clean after
      #   work is done.
      def shutdown
        # There is a case, where the consumer no longer exists because it was revoked, in case like
        # that we do not build a new instance and shutdown should not be triggered.
        consumer.on_shutdown if @consumer
      end

      private

      # @return [Object] cached consumer instance
      def consumer
        @consumer ||= begin
          topic = @coordinator.topic

          strategy = strategy_selector.find(topic)
          expansions = expansions_selector.find(topic)

          consumer = topic.consumer_class.new
          # We use singleton class as the same consumer class may be used to process different
          # topics with different settings
          consumer.singleton_class.include(strategy)

          # Specific features may expand consumer API beyond the injected strategy. The difference
          # here is that strategy impacts the flow of states while extra APIs just provide some
          # extra methods with informations, etc but do no deviate the flow behavior
          expansions.each { |expansion| consumer.singleton_class.include(expansion) }

          consumer.client = @client
          consumer.coordinator = @coordinator
          # We assign producer only when not available already. It may already be available if
          # user redefined the `#producer` method for example. This can be useful for example when
          # having a multi-cluster setup and using a totally custom producer
          consumer.producer ||= ::Karafka::App.producer
          # Since we have some message-less flows (idle, etc), we initialize consumer with empty
          # messages set. In production we have persistent consumers, so this is not a performance
          # overhead as this will happen only once per consumer lifetime
          consumer.messages = empty_messages

          # Run the post-initialization hook for users that need to run some actions when consumer
          # is built and ready (all basic state and info).
          # Users should **not** overwrite the `#initialize` because it won't have all the needed
          # data assigned yet.
          consumer.on_initialized

          consumer
        end
      end

      # Initializes the messages set in case given operation would happen before any processing
      # This prevents us from having no messages object at all as the messages object and
      # its metadata may be used for statistics
      def empty_messages
        Messages::Builders::Messages.call(
          [],
          topic,
          partition,
          Time.now
        )
      end
    end
  end
end
