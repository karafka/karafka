# frozen_string_literal: true

module Karafka
  module Connection
    class Client
      # Namespace for the two polling strategies that Client can use.
      #
      # The appropriate strategy is selected once during Client initialization based on
      # the enable.partition.eof Kafka config flag and extended onto the instance.
      module PollingStrategies
      end
    end
  end
end
