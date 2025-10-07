# frozen_string_literal: true

# Consumer for processing user-related events
class UsersConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:users_messages] << message.raw_payload
    end
  end
end
