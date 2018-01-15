# frozen_string_literal: true

module Karafka
  # Responders namespace encapsulates all the internal responder implementation parts
  module Responders
    # Responders builder is used to finding (based on the consumer class name) a responder
    # that match the consumer. We use it when user does not provide a responder inside routing,
    # but he still names responder with the same convention (and namespaces) as consumer
    #
    # @example Matching responder exists
    #   Karafka::Responder::Builder(NewEventsConsumer).build #=> NewEventsResponder
    # @example Matching responder does not exist
    #   Karafka::Responder::Builder(NewBuildsConsumer).build #=> nil
    class Builder
      # @param consumer_class [Karafka::BaseConsumer, nil] descendant of
      #   Karafka::BaseConsumer
      # @example Tries to find a responder that matches a given consumer. If nothing found,
      #   will return nil (nil is accepted, because it means that a given consumer don't
      #   pipe stuff further on)
      def initialize(consumer_class)
        @consumer_class = consumer_class
      end

      # Tries to figure out a responder based on a consumer class name
      # @return [Class] Responder class (not an instance)
      # @return [nil] or nil if there's no matching responding class
      def build
        Helpers::ClassMatcher.new(
          @consumer_class,
          from: 'Consumer',
          to: 'Responder'
        ).match
      end
    end
  end
end
