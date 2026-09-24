# frozen_string_literal: true

module Karafka
  # Namespace for the consumer class hierarchy. Consumers are split by mode the same way routing
  # is: a mode-agnostic {Base} plus per-mode subclasses ({ConsumerGroup}, {ShareGroup}).
  module Consumers
    # Mode-agnostic base for all Karafka consumers. It carries only the machinery shared by both
    # consumer-group and share-group (KIP-932) consumers - message access, the producer, the
    # generic lifecycle dispatch and instrumentation. Mode-specific behavior (offset management,
    # pausing, seeking and partition eof/revocation for consumer groups; acknowledgements for
    # share groups) lives in the subclasses.
    #
    # @note This is not meant to be inherited from directly by end users. Consumer-group consumers
    #   inherit from {Karafka::BaseConsumer} (an alias of {ConsumerGroup}); share-group consumers
    #   inherit from {ShareGroup}.
    class Base
      # Allow for consumer instance tagging for instrumentation
      include Karafka::Core::Taggable
      include Helpers::ConfigImporter.new(
        monitor: %i[monitor],
        critical_errors: %i[internal processing critical_errors]
      )

      extend Forwardable

      def_delegators :@coordinator, :topic, :partition

      def_delegators(
        :producer, :produce_async, :produce_sync, :produce_many_async, :produce_many_sync
      )

      def_delegators :messages, :each

      # @return [String] id of the current consumer
      attr_reader :id
      # @return [Karafka::Messages::Messages] current messages batch
      attr_accessor :messages
      # @return [Karafka::Connection::Client] kafka connection client
      attr_accessor :client
      # @return [Object] coordinator
      attr_accessor :coordinator
      # @return [Waterdrop::Producer] producer instance
      attr_accessor :producer

      # Creates new consumer and assigns it an id
      def initialize
        @id = SecureRandom.hex(6)
        @used = false
      end

      # @return [Symbol] the mode of this consumer (`:consumer` / `:share`). Overridden by
      #   subclasses.
      # @raise [NotImplementedError] when not overridden
      def group_type
        raise NotImplementedError, "Implement in a subclass"
      end

      # @return [Boolean] true when this is a consumer-group consumer
      def consumer_group?
        group_type == :consumer
      end

      # @return [Boolean] true when this is a share-group consumer
      def share_group?
        group_type == :share
      end

      # Trigger method running after consumer is fully initialized.
      #
      # @private
      def on_initialized
        handle_initialized
      rescue => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          type: "consumer.initialized.error"
        )
      end

      # Can be used to run preparation code prior to the job being enqueued
      #
      # @private
      # @note This should not be used by the end users as it is part of the lifecycle of things and
      #   not as a part of the public api. This should not perform any extensive operations as it is
      #   blocking and running in the listener thread.
      def on_before_schedule_consume
        @used = true
        handle_before_schedule_consume
      end

      # Can be used to run preparation code in the worker
      #
      # @private
      # @note This should not be used by the end users as it is part of the lifecycle of things and
      #   not as part of the public api. This can act as a hook when creating non-blocking
      #   consumers and doing other advanced stuff
      def on_before_consume
        messages.metadata.processed_at = Time.now
        messages.metadata.freeze

        # We run this after the full metadata setup, so we can use all the messages information
        # if needed
        handle_before_consume
      end

      # Executes the default wrapping flow
      #
      # @private
      #
      # @param action [Symbol]
      def on_wrap(action, &)
        handle_wrap(action, &)
      rescue => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          type: "consumer.wrap.error"
        )
      end

      # Can be used to run code prior to scheduling of idle execution
      #
      # @private
      def on_before_schedule_idle
        handle_before_schedule_idle
      end

      # Trigger method for running on idle runs without messages
      #
      # @private
      def on_idle
        handle_idle
      end

      # Can be used to run code prior to scheduling of revoked execution
      #
      # @private
      def on_before_schedule_shutdown
        handle_before_schedule_shutdown
      end

      # Trigger method for running on shutdown.
      #
      # @private
      def on_shutdown
        handle_shutdown
      rescue => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          type: "consumer.shutdown.error"
        )
      end

      # Returns a string representation of the consumer instance for debugging purposes.
      #
      # This method provides a safe inspection that avoids walking through potentially large
      # nested objects like messages, client connections, or coordinator state that could
      # cause performance issues during logging or debugging.
      #
      # @return [String] formatted string containing essential consumer information including
      #   consumer ID, topic name, partition number, usage status, message count, and
      #   revocation status
      def inspect
        parts = [
          "id=#{@id}",
          "topic=#{topic&.name.inspect}",
          "partition=#{partition}",
          "used=#{@used}",
          "messages_count=#{@messages&.count}",
          "revoked=#{coordinator&.revoked?}"
        ]

        "#<#{self.class.name}:#{format("%#x", object_id)} #{parts.join(" ")}>"
      end

      private

      # Method called post-initialization of a consumer when all basic things are assigned.
      # Since initialization via `#initialize` is complex and some states are set a bit later, this
      # hook allows to initialize resources once at a time when topic, partition and other things
      # are assigned to the consumer
      #
      # @note Please keep in mind that it will run many times when persistence is off. Basically
      #   once each batch.
      def initialized
      end

      # Method that will perform business logic and on data received from Kafka (it will consume
      #   the data)
      # @note This method needs to be implemented in a subclass. We stub it here as a failover if
      #   someone forgets about it or makes on with typo
      def consume
        raise NotImplementedError, "Implement this in a subclass"
      end

      # This method can be redefined to build a wrapping API around user code + karafka flow control
      # code starting from the user code (operations prior to that are not part of this).
      # The wrapping relates to a single job flow.
      #
      # Karafka framework may require user configured "state" like for example a selected
      # transactional producer that should be used not only by the user but also by the framework.
      # By using this API user can checkout a producer and return it to the pool.
      #
      # @param _action [Symbol] what action are we wrapping. Useful if we want for example to only
      #   wrap the `:consume` action.
      # @yield Runs the execution block
      #
      # @note User related errors should not leak to this level of execution. This should not be
      #   used for anything consumption related but only for setting up state that that Karafka
      #   code may need outside of user code.
      #
      # @example Redefine to use a producer from a pool for consume
      #   def wrap(action)
      #     # Do not checkout producer for any other actions
      #     return yield unless action == :consume
      #
      #     default_producer = self.producer
      #
      #     $producers.with do |producer|
      #       self.producer = producer
      #       yield
      #     end
      #
      #     self.producer = default_producer
      #   end
      def wrap(_action)
        yield
      end

      # Method that will be executed when the process is shutting down. You can use it for
      # some teardown procedures (closing file handler, etc).
      def shutdown
      end

      # @return [Boolean] was this consumer in active use. Active use means running `#consume` at
      #   least once. Consumer may have to run `#revoked` or `#shutdown` despite not running
      #   `#consume` previously in delayed job cases and other cases that potentially involve
      #   running the idle housekeeping job
      def used?
        @used
      end

      # @param error [Exception, nil] error to check or nil when none was recorded
      # @return [Boolean] is the error one of the process-critical ones (configurable via the
      #   `internal.processing.critical_errors` setting)
      def critical_error?(error)
        return false unless error

        critical_errors.any? { |type| error.is_a?(type) }
      end
    end
  end
end
