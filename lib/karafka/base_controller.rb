require 'karafka/concerns/before_action'
# Karafka module namespace
module Karafka
  # Base controller
  class BaseController
    extend Karafka::Concerns::BeforeAction

    def initialize(params)
      # rubocop:disable all
      @@params = JSON.load(params)
      # rubocop:enable all
    end

    # Method which should be redefined for all descendants.
    def process
      fail NotImplementedError
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
