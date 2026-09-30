# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Builds and drives a share-group consumer for a given topic. There is no eofed/revoked
      # lifecycle and no partitioner - a poll batch is handed to a single consumer instance which
      # acknowledges records per message. The processing strategy is {Strategies::Default}.
      class Executor
        extend Forwardable

        def_delegators :@coordinator, :topic, :partition

        # @return [String] unique id for state tracking
        attr_reader :id

        # @return [String] subscription group id to which this executor belongs
        attr_reader :group_id

        # @return [Karafka::Processing::ShareGroups::Coordinator]
        attr_reader :coordinator

        # @param group_id [String] subscription group id this executor reports work under
        # @param client [Karafka::Connection::ShareGroups::Client] share client
        # @param coordinator [Karafka::Processing::ShareGroups::Coordinator]
        def initialize(group_id, client, coordinator)
          @id = SecureRandom.hex(6)
          @group_id = group_id
          @client = client
          @coordinator = coordinator
        end

        # Prepares the consumer with the batch of messages prior to running consumption.
        #
        # @param messages [Array<Karafka::Messages::Message>] batch of messages to consume
        def before_schedule_consume(messages)
          # Recreate the consumer with each batch when persistence is disabled, same as consumer
          # groups, for a consistent behavior regardless of the setting.
          @consumer = nil unless topic.consumer_persistence

          consumer.messages = Messages::Builders::Messages.call(
            messages,
            topic,
            partition,
            Time.now
          )

          consumer.on_before_schedule_consume
        end

        # Runs setup/warm-up code prior to consumption
        def before_consume
          consumer.on_before_consume
        end

        # Runs the wrap/around execution context for a given action
        # @param action [Symbol]
        def wrap(action, &)
          consumer.on_wrap(action, &)
        end

        # Runs the user consumption code
        def consume
          consumer.on_consume
        end

        # Runs the post-consumption code (acknowledgement flush)
        def after_consume
          consumer.on_after_consume
        end

        # Runs the code needed before the idle job is scheduled (in the listener thread)
        def before_schedule_idle
          consumer.on_before_schedule_idle
        end

        # Runs the consumer idle housekeeping. This runs when a poll returns no records, so the
        # consumer can perform periodic work even without new messages to process.
        def idle
          consumer.on_idle
        end

        # Runs the code needed before the shutdown job is scheduled (in the listener thread)
        def before_schedule_shutdown
          consumer.on_before_schedule_shutdown if @consumer
        end

        # Runs the shutdown code when the process is stopping
        def shutdown
          # The consumer may not exist if nothing was ever consumed on this executor
          consumer.on_shutdown if @consumer
        end

        private

        # @return [Karafka::Consumers::ShareGroup] cached consumer instance
        def consumer
          @consumer ||= begin
            topic = @coordinator.topic

            consumer = topic.consumer_class.new
            # We use the singleton class as the same consumer class may process different topics
            # with different settings
            consumer.singleton_class.include(Strategies::Default)

            consumer.client = @client
            consumer.coordinator = @coordinator
            consumer.producer ||= Karafka::App.producer
            # Initialize with an empty batch so message-less flows (shutdown, etc.) still have a
            # messages object available
            consumer.messages = empty_messages

            consumer.on_initialized

            consumer
          end
        end

        # @return [Karafka::Messages::Messages] empty messages batch used before any consumption
        def empty_messages
          Messages::Builders::Messages.call(
            [],
            @coordinator.topic,
            @coordinator.partition,
            Time.now
          )
        end
      end
    end
  end
end
