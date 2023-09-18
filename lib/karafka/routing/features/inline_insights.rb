# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        class << self
          def post_setup(config)
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
                          .any?(&:inline_statistics?)

              require 'karafka/instrumentation/vendors/karafka/inline/tracker'
              require 'karafka/instrumentation/vendors/karafka/inline/listener'

              ::Karafka::Instrumentation::InlineInsights::Tracker.instance

              ::Karafka.monitor.subscribe(
                ::Karafka::Instrumentation::InlineInsights::Listener.new
              )
            end
          end
        end
      end
    end
  end
end
