# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Feature allowing us to get visibility during the consumption into metrics of particular
      # partition we operate on. It can be useful when making context-aware consumers that change
      # their behaviours based on the lag and other parameters.
      class InlineInsights < Base
        class << self
          # If needed installs the needed listener and initializes tracker
          #
          # @param _config [Karafka::Core::Configurable::Node] app config
          def post_setup(_config)
            ::Karafka::App.monitor.subscribe('app.running') do
              # Do not activate tracking of statistics if none of our active topics uses it
              # This prevents us from tracking metrics when user just runs a subset of topics
              # in a given process and none of those actually utilizes this feature
              next unless ::Karafka::App
                          .subscription_groups
                          .values
                          .flat_map(&:itself)
                          .flat_map(&:topics)
                          .flat_map(&:to_a)
                          .any?(&:inline_insights?)

              # Initialize the tracker prior to becoming multi-threaded
              ::Karafka::Processing::InlineInsights::Tracker.instance

              # Subscribe to the statistics reports and collect them
              ::Karafka.monitor.subscribe(
                ::Karafka::Processing::InlineInsights::Listener.new
              )
            end
          end
        end
      end
    end
  end
end
