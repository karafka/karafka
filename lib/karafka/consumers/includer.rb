# frozen_string_literal: true

module Karafka
  # Additional functionalities for consumers
  module Consumers
    # Module used to inject functionalities into a given consumer instance, based on the consumer
    # topic and its settings
    # We don't need all the behaviors in all the cases, so it is not worth having everything
    # in all the cases all the time
    module Includer
      class << self
        # @param consumer [Karafka::BaseConsumer] consumer instance, that will get some
        #   functionalities based on the topic under which it operates
        def call(consumer)
          topic = consumer.topic

          bind_backend(consumer, topic)
          bind_params(consumer, topic)
          bind_batch_metadata(consumer, topic)
          bind_responders(consumer, topic)
        end

        private

        # Figures out backend for a given consumer class, based on the topic backend and
        #   includes it into the consumer class
        # @param consumer [Karafka::BaseConsumer] consumer instance
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_backend(consumer, topic)
          backend = Kernel.const_get("::Karafka::Backends::#{topic.backend.to_s.capitalize}")
          consumer.extend(backend)
        end

        # Adds a single #params support for non batch processed topics
        # @param consumer [Karafka::BaseConsumer] consumer instance
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_params(consumer, topic)
          return if topic.batch_consuming

          consumer.extend(SingleParams)
        end

        # Adds an option to work with batch metadata for consumer instances that have
        #   batch fetching enabled
        # @param consumer [Karafka::BaseConsumer] consumer instance
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_batch_metadata(consumer, topic)
          return unless topic.batch_fetching

          consumer.extend(BatchMetadata)
        end

        # Adds responders support for topics and consumers with responders defined for them
        # @param consumer [Karafka::BaseConsumer] consumer instance
        # @param topic [Karafka::Routing::Topic] topic of a consumer class
        def bind_responders(consumer, topic)
          return unless topic.responder

          consumer.extend(Responders)
        end
      end
    end
  end
end
