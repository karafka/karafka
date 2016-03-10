module Karafka
  # Internal stuff related to workers
  module Workers
    # Builder is used to check if there is a proper controller with the same name as
    # a controller and if not, it will create a default one using Karafka::BaseWorker
    # This is used as a building layer between controllers and workers. it will be only used
    # when user does not provide his own worker that should perform controller stuff
    class Builder
      # Regexp used to remove any non classy like characters that might be in the controller
      # class name (if defined dynamically, etc)
      CONSTANT_REGEXP = %r{[?!=+\-\*/\^\|&\[\]<>%~\#\:]}

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
        return self.class.const_get(name) if self.class.const_defined?(name)

        klass = Class.new(base)

        scope.const_set(name, klass)
      end

      private

      # @return [Class, Module] scope to which we want to assign a built worker class
      # @note If there is no scope, we should attach directly to Object
      # @example Controller name not namespaced: 'SuperController'
      #   scope #=> Object
      # @example Controller name namespace: 'Videos::NewVideosController'
      #   scope #=> Videos
      def scope
        enclosing = @controller_class.to_s.to_s.split('::')[0...-1]
        return Object if enclosing.empty?
        Object.const_get(enclosing.join('::'))
      end

      # @return [String] stringified theoretical worker class name
      # @note It will return only controller name, without
      # @example Controller name: 'SuperController'
      #   name #=> 'SuperWorker'
      # @example Controller name: 'Videos::NewVideosController'
      #   name #=> 'NewVideosWorker'
      def name
        base = @controller_class.to_s.split('::').last
        base.gsub!('Controller', 'Worker')
        base.gsub!(CONSTANT_REGEXP, '')
        base
      end

      # @return [Class] descendant of Karafka::BaseWorker from which all other workers
      #   should inherit
      # @raise [Karafka::Errors::BaseWorkerDescentantMissing] raised when Karafka cannot detect
      #   direct Karafka::BaseWorker descendant from which it could build workers
      def base
        Karafka::BaseWorker.subclasses.first || raise(Errors::BaseWorkerDescentantMissing)
      end
    end
  end
end
