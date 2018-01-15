# frozen_string_literal: true

module Karafka
  # Additional functionalities for consumers
  module Consumers
    # Module used to inject functionalities into a given consumer class, based on the consumer
    # topic and its settings
    # We don't need all the behaviors in all the cases, so it is not worth having everything
    # in all the cases all the time
    module Includer
      class << self
        # @param consumer_class [Class] consumer class, that will get some functionalities
        #   based on the topic under which it operates
        def call(consumer_class)
          topic = consumer_class.topic

          bind_backend(consumer_class, topic)
          bind_params(consumer_class, topic)
          bind_responders(consumer_class, topic)
        end

        private

        # Figures out backend for a given consumer class, based on the topic backend and
        #   includes it into the consumer class
        # @param consumer_class [Class] consumer class
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_backend(consumer_class, topic)
          backend = Kernel.const_get("::Karafka::Backends::#{topic.backend.to_s.capitalize}")
          consumer_class.include backend
        end

        # Adds a single #params support for non batch processed topics
        # @param consumer_class [Class] consumer class
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_params(consumer_class, topic)
          return if topic.batch_consuming
          consumer_class.include SingleParams
        end

        # Adds responders support for topics and consumers with responders defined for them
        # @param consumer_class [Class] consumer class
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_responders(consumer_class, topic)
          return unless topic.responder
          consumer_class.include Responders
        end
      end
    end
  end
end
