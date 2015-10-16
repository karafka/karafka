module Karafka
  # Class-wrapper for hash with indifferent access
  class Params < HashWithIndifferentAccess
    # Builds params instance based on message
    # @param message [Karafka::Connection::Message] single incoming message
    # @param parser [Parser] parser which is use to parse message content
    # @return [Karafka::Params] params instance
    def self.build(message, parser)
      # Sidekiq returns us a hash already - so we will just convert it into
      # a indifferent access version
      return new(message.content) if message.content.is_a?(Hash)

      new(parser.parse(message.content))
    rescue parser::ParserError
      return new(message: message.content)
    end
  end
end
