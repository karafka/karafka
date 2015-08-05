require 'karafka/concerns/before_action'
# Karafka module namespacegit
module Karafka
  # Base controller
  class BaseController
    extend Karafka::Concerns::BeforeAction

    def initialize(params)
      @params = JSON.load(params)
    end

    # Method which should be redefined for all descendants.
    def process
      fail NotImplementedError
    end

    # params method to get instance variable of params
    def params
      instance_variable_get :@params
    end

    class << self
      attr_accessor :group, :topic

      # Method which finds all descendants of BaseController
      def descendants
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end
    end
  end
end
