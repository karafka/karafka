# frozen_string_literal: true

module Karafka
  # Additional functionalities for controllers
  module Controllers
    # Module used to inject functionalities into a given controller class, based on the controller
    # topic and its settings
    # We don't need all the behaviors in all the cases, so it is totally not worth having
    # everything in all the cases all the time
    module Includer
      # @param controller_class [Class] controller class, that will get some functionalities
      #   based on the topic under which it operates
      def self.call(controller_class)
        topic = controller_class.topic
        controller_class.include InlineBackend if topic.processing_backend == :inline
        controller_class.include SidekiqBackend if topic.processing_backend == :sidekiq
        controller_class.include SingleParams unless topic.batch_processing
        controller_class.include Responders if topic.responder
      end
    end
  end
end
