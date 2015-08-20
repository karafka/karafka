module Karafka
  # Class-wrapper for hash with indifferent access
  class Params < HashWithIndifferentAccess
    # Builds params instance based on event
    # @param event [Karafka::Connection::Event] single incoming event
    # @return [Karafka::Params] params instance
    def self.build(event)
      # Sidekiq returns us a hash already - so we will just convert it into
      # a indifferent access version
      return new(event.message) if event.message.is_a?(Hash)

      new(JSON.parse(event.message))
    rescue JSON::ParserError
      return new(message: event.message)
    end
  end
end
