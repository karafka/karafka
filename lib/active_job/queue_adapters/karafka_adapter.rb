# frozen_string_literal: true

# ActiveJob components to allow for jobs consumption with Karafka
module ActiveJob
  # ActiveJob queue adapters
  module QueueAdapters
    # Karafka adapter for enqueuing jobs
    # This is here for ease of integration with ActiveJob. See `::Karafka::ActiveJob::Adapter` if
    # you are interested in how it works and `::Karafka::Pro::ActiveJob::Adapter` to see what
    # additional functionalities are provided with the Pro Adapter
    class KarafkaAdapter
    end
  end
end
