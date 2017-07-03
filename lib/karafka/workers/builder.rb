# frozen_string_literal: true

module Karafka
  # Internal stuff related to workers
  module Workers
    # Builder is used to check if there is a proper controller with the same name as
    # a controller and if not, it will create a default one using Karafka::BaseWorker
    # This is used as a building layer between controllers and workers. it will be only used
    # when user does not provide his own worker that should perform controller stuff
    class Builder
      # @param controller_class [Karafka::BaseController] descendant of Karafka::BaseController
      # @example Create a worker builder
      #   Karafka::Workers::Builder.new(SuperController)
      def initialize(controller_class)
        @controller_class = controller_class
      end

      # @return [Class] Sidekiq worker class that already exists or new build based
      #   on the provided controller_class name
      # @example Controller: SuperController
      #   build #=> SuperWorker
      # @example Controller: Videos::NewVideosController
      #   build #=> Videos::NewVideosWorker
      def build
        return matcher.match if matcher.match
        klass = Class.new(base)
        matcher.scope.const_set(matcher.name, klass)
      end

      private

      # @return [Class] descendant of Karafka::BaseWorker from which all other workers
      #   should inherit
      # @raise [Karafka::Errors::BaseWorkerDescentantMissing] raised when Karafka cannot detect
      #   direct Karafka::BaseWorker descendant from which it could build workers
      def base
        Karafka::BaseWorker.subclasses.first || raise(Errors::BaseWorkerDescentantMissing)
      end

      # @return [Karafka::Helpers::ClassMatcher] matcher instance for matching between controller
      #   and appropriate worker
      def matcher
        @matcher ||= Helpers::ClassMatcher.new(
          @controller_class,
          from: 'Controller',
          to: 'Worker'
        )
      end
    end
  end
end
