# frozen_string_literal: true

module Karafka
  module AssignmentStrategies
    class RoundRobin < SimpleDelegator
      def initialize
        super(Kafka::RoundRobinAssignmentStrategy.new)
      end
    end
  end
end
