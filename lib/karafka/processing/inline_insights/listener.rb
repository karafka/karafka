# frozen_string_literal: true

module Karafka
  module Processing
    module InlineInsights
      # Listener that adds statistics to our inline tracker
      class Listener
        # Adds statistics to the tracker
        # @param event [Karafka::Core::Monitoring::Event] event with statistics
        def on_statistics_emitted(event)
          Tracker.add(
            event[:consumer_group_id],
            event[:statistics]
          )
        end
      end
    end
  end
end
