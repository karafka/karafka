module Karafka
  # Class-wrapper for hash with indifferent access with additional lazy loading feature
  class Params < HashWithIndifferentAccess
    # Builds params instance based on message
    # @param message [Karafka::Connection::Message] single incoming message
    # @param controller [Karafka::BaseController] base controller descendant
    # @return [Karafka::Params] params instance
    # @note You can check if a given instance was parsed by executing the #parsed? method
    def initialize(message, controller)
      # Internally here we don't care about a controller instance but just about the
      # class itself and its attributes
      @controller_class = controller.class
      @message = message
      @parsed = false
      @received_at = Time.now
    end

    # @return [Karafka::Params] will return self (always) but will parse data if it was not
    #   yet parsed and loaded
    def fetch
      parse! unless @parsed

      self
    end

    private

    # Tries to parse content and merge it with this hash instance and does the same
    # with metadata
    def parse!
      merge!(content)
      merge!(metadata)
      @parsed = true
    end

    # @return [Hash] hash with parsed data
    # @note Data is being parsed using controller#parser object
    # @note If we cannot parse it, we will take the raw content and wrap it
    def content
      # If the message itself is a hash, than there is no need to parse it again
      # This scenario happes when we take message from sidekiq params
      return @message if @message.is_a?(Hash)

      # If it was not a hash, then it means that it is probably something that we should
      # try to parse
      @controller_class.parser.parse(@message.content)
    rescue @controller_class.parser::ParserError
      return { message: @message.content }
    end

    # @return [Hash] hash with metadata parameters that might be useful
    def metadata
      {
        controller: @controller_class,
        worker: @controller_class.worker,
        parser: @controller_class.parser,
        topic: @controller_class.topic,
        received_at: @received_at
      }
    end
  end
end
