# frozen_string_literal: true

# Consumer for processing order-related events
class OrdersConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:orders_messages] << message.raw_payload
    end
  end
end
