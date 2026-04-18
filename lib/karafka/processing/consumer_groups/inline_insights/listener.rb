# frozen_string_literal: true

module Karafka
  module Processing
    # Consumer-group-specific processing components (driven by rebalance callbacks and partition
    # ticks). Parallel `ShareGroups` will live next to this namespace once KIP-932 lands.
    module ConsumerGroups
      module InlineInsights
        # Listener that adds statistics to our inline tracker
        class Listener
          # Adds statistics to the tracker
          # @param event [Karafka::Core::Monitoring::Event] event with statistics
          def on_statistics_emitted(event)
            Tracker.add(
              event[:group_id],
              event[:statistics]
            )
          end
        end
      end
    end
  end
end
