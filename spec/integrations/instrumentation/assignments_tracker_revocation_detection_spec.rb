# frozen_string_literal: true

# This spec demonstrates using Fiber storage to pass context (topic, partition)
# to helper classes without explicit arguments, enabling them to check assignment status.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

# Simulates expensive computation that checks assignment ownership
# Uses Fiber storage to access context without requiring arguments
class ExpensiveComputation
  class << self
    def perform
      # Simulate long processing
      # Check ownership periodically using Fiber storage (no context passed as args!)
      loop do
        sleep(0.5)

        next unless revoked?

        DT[:revoked] = true

        return
      end
    end

    private

    def revoked?
      topic = Fiber.current.storage[:karafka_context][:topic]
      partition = Fiber.current.storage[:karafka_context][:partition]

      assignments = Karafka::App.assignments[topic] || []

      !assignments.include?(partition)
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    Fiber[:karafka_context] = {
      topic: topic,
      partition: partition
    }

    # Call computation class that uses Fiber storage internally
    ExpensiveComputation.perform
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(:revoked)
end
