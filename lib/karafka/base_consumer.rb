# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base consumer from which all Karafka consumers should inherit
  class BaseConsumer
    extend Forwardable

    # Allows us to mark messages as consumed for non-automatic mode without having
    # to use consumer client directly. We do this that way, because most of the people should not
    # mess with the client instance directly (just in case)
    %i[
      mark_as_consumed
      mark_as_consumed!
      trigger_heartbeat
      trigger_heartbeat!
    ].each do |delegated_method_name|
      def_delegator :client, delegated_method_name

      private delegated_method_name
    end

    # @return [Karafka::Routing::Topic] topic to which a given consumer is subscribed
    attr_reader :topic
    # @return [Karafka::Params:ParamsBatch] current params batch
    attr_accessor :params_batch

    # Assigns a topic to a consumer and builds up proper consumer functionalities
    #   so that it can cooperate with the topic settings
    # @param topic [Karafka::Routing::Topic]
    def initialize(topic)
      @topic = topic
      Consumers::Includer.call(self)
    end

    # Executes the default consumer flow.
    def call
      process
    end

    private

    # @return [Karafka::Connection::Client] messages consuming client that can be used to
    #    commit manually offset or pause / stop consumer based on the business logic
    def client
      Persistence::Client.read
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
