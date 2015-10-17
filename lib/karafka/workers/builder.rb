module Karafka
  module Workers
    # Builder is used to check if there is a proper controller with the same name as
    # a controller and if not, it will create a default one using Karafka::Workers::BaseWorker
    # This is used as a building layer between controllers and workers. it will be only used
    # when user does not provide his own worker that should perform controller stuff
    class Builder
      # Regexp used to remove any non classy like characters that might be in the controller
      # class name (if defined dynamically, etc)
      CONSTANT_REGEXP = %r{[?!=+\-\*/\^\|&\[\]<>%~\#\:]}

      # @param controller [Karafka::BaseController] descendant of Karafka::BaseController
      # @example Create a worker builder
      #   Karafka::Workers::Builder.new(SuperController)
      def initialize(controller)
        @controller = controller
      end

      # @return [Class] Sidekiq worker class that already exists or new build based
      #   on the provided controller name
      # @example Controller: SuperController
      #   build #=> SuperWorker
      # @example Controller: Videos::NewVideosController
      #   build #=> Videos::NewVideosWorker
      def build
        return self.class.const_get(name) if self.class.const_defined?(name)

        klass = Class.new(Karafka::Workers::BaseWorker)

        klass.timeout = Karafka::App.config.worker_timeout
        klass.logger = Karafka::App.logger

        Object.const_set(name, klass)
      end

      private

      # @return [String] stringified theoretical worker class name
      # @example Controller name: 'SuperController'
      #   name #=> 'SuperWorker'
      # @example Controller name: 'Videos::NewVideosController'
      #   name #=> 'Videos::NewVideosWorker'
      def name
        parts = @controller.to_s.split('::')
        parts.map! do |part|
          part.gsub!('Controller', 'Worker')
          part.gsub!(CONSTANT_REGEXP, '')
          part
        end

        parts.join('::')
      end
    end
  end
end
