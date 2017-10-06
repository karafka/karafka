# frozen_string_literal: true

module Karafka
  module Routing
    # Default topic mapper that does not remap things
    # Mapper can be used for Kafka providers that require namespaced topic names. Instead of being
    # provider dependent, we can then define mapper and use internally "pure" topic names in
    # routes and responders
    #
    # @example Mapper for mapping prefixed topics
    #   module MyMapper
    #     PREFIX = "my_user_name."
    #
    #     def incoming(topic)
    #       topic.to_s.gsub(PREFIX, '')
    #     end
    #
    #     def outgoing(topic)
    #       "#{PREFIX}#{topic}"
    #     end
    #   end
    #
    # @example Mapper for replacing "." with "_" in topic names
    #   module MyMapper
    #     PREFIX = "my_user_name."
    #
    #     def incoming(topic)
    #       topic.to_s.gsub('.', '_')
    #     end
    #
    #     def outgoing(topic)
    #       topic.to_s.gsub('_', '.')
    #     end
    #   end
    module TopicMapper
      class << self
        # @param topic [String, Symbol] topic
        # @return [String, Symbol] same topic as on input
        # @example
        #   incoming('topic_name') #=> 'topic_name'
        def incoming(topic)
          topic
        end

        # @param topic [String, Symbol] topic
        # @return [String, Symbol] same topic as on input
        # @example
        #   outgoing('topic_name') #=> 'topic_name'
        def outgoing(topic)
          topic
        end
      end
    end
  end
end
