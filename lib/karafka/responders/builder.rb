# frozen_string_literal: true

module Karafka
  # Responders namespace encapsulates all the internal responder implementation parts
  module Responders
    # Responders builder is used to find (based on the controller class name) a responder that
    # match the controller. This is used when user does not provide a responder inside routing
    # but he still names responder with the same convention (and namespaces) as controller
    # @example Matching responder exists
    #   Karafka::Responder::Builder(NewEventsController).build #=> NewEventsResponder
    # @example Matching responder does not exist
    #   Karafka::Responder::Builder(NewBuildsController).build #=> nil
    class Builder
      # @param controller_class [Karafka::BaseController, nil] descendant of
      #   Karafka::BaseController
      # @example Tries to find a responder that matches a given controller. If nothing found,
      #   will return nil (nil is accepted, because it means that a given controller don't
      #   pipe stuff further on)
      def initialize(controller_class)
        @controller_class = controller_class
      end

      # Tries to figure out a responder based on a controller class name
      # @return [Class] Responder class (not an instance)
      # @return [nil] or nil if there's no matching responding class
      def build
        Helpers::ClassMatcher.new(
          @controller_class,
          from: 'Controller',
          to: 'Responder'
        ).match
      end
    end
  end
end
