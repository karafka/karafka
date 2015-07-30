module Karafka
  # Event module which encapsulate event logic
  class Event
    attr_reader :topic, :message

    def initialize(topic, message)
      @topic = topic
      @message = message
    end

    # Create pool with Poseidon producer which send messages
    def send!
      return true unless ::Karafka.config.send_events?

      message_to_send = Poseidon::MessageToSend.new(
        topic,
        message.to_json
      )

      Pool.with do |producer|
        producer.send_messages([message_to_send])
      end
    end
  end
end
