# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base controller from which all Karafka controllers should inherit
  class BaseController
    extend ActiveSupport::DescendantsTracker
    extend Forwardable

    # Allows us to mark messages as consumed for non-automatic mode without having
    # to use consumer directly. We do this that way, because most of the people should not
    # mess with the consumer instance directly (just in case)
    def_delegator :consumer, :mark_as_consumed

    private :mark_as_consumed

    class << self
      attr_reader :topic

      # Assigns a topic to a controller and build up proper controller functionalities, so it can
      #   cooperate with the topic settings
      # @param topic [Karafka::Routing::Topic]
      # @return [Karafka::Routing::Topic] assigned topic
      def topic=(topic)
        @topic = topic
        Controllers::Includer.call(self)
      end
    end

    # @return [Karafka::Routing::Topic] topic to which a given controller is subscribed
    def topic
      self.class.topic
    end

    # Creates lazy loaded params batch object
    # @note Until first params usage, it won't parse data at all
    # @param messages [Array<Kafka::FetchedMessage>, Array<Hash>] messages with raw
    #   content (from Kafka) or messages inside a hash (from backend, etc)
    # @return [Karafka::Params::ParamsBatch] lazy loaded params batch
    def params_batch=(messages)
      @params_batch = Karafka::Params::ParamsBatch.new(messages, topic.parser)
    end

    # Executes the default controller flow.
    def call
      process
    end

    private

    # We make it private as it should be accesible only from the inside of a controller
    attr_reader :params_batch

    # @return [Karafka::Connection::Consumer] messages consumer that can be used to
    #    commit manually offset or pause / stop consumer based on the business logic
    def consumer
      Persistence::Consumer.read
    end

    # Method that will perform business logic and on data received from Kafka (it will consume
    #   the data)
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def consume
      raise NotImplementedError, 'Implement this in a subclass'
    end
  end
end
