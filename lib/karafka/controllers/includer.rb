# frozen_string_literal: true

module Karafka
  # Additional functionalities for controllers
  module Controllers
    # Module used to inject functionalities into a given controller class, based on the controller
    # topic and its settings
    # We don't need all the behaviors in all the cases, so it is totally not worth having
    # everything in all the cases all the time
    module Includer
      class << self
        # @param controller_class [Class] controller class, that will get some functionalities
        #   based on the topic under which it operates
        def call(controller_class)
          topic = controller_class.topic

          bind_backend(controller_class, topic)
          bind_params(controller_class, topic)
          bind_responders(controller_class, topic)
        end

        private

        # Figures out backend for a given controller class, based on the topic backend and
        #   includes it into the controller class
        # @param controller_class [Class] controller class
        # @param topic [Karafka::Routing::Topic] topic of a controller class
        def bind_backend(controller_class, topic)
          backend = Kernel.const_get("::Karafka::Backends::#{topic.backend.to_s.capitalize}")
          controller_class.include backend
        end

        # Adds a single #params support for non batch processed topics
        # @param controller_class [Class] controller class
        # @param topic [Karafka::Routing::Topic] topic of a controller class
        def bind_params(controller_class, topic)
          return if topic.batch_processing
          controller_class.include SingleParams
        end

        # Adds responders support for topics and controllers with responders defined for them
        # @param controller_class [Class] controller class
        # @param topic [Karafka::Routing::Topic] topic of a controller class
        def bind_responders(controller_class, topic)
          return unless topic.responder
          controller_class.include Responders
        end
      end
    end
  end
end
