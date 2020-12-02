# frozen_string_literal: true

module Karafka
  # Strategies for Kafka partitions assignments
  module AssignmentStrategies
    # Standard RoundRobin strategy
    class RoundRobin < SimpleDelegator
      def initialize
        super(Kafka::RoundRobinAssignmentStrategy.new)
      end
    end
  end
end
