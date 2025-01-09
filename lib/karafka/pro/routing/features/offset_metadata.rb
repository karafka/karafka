# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Offset Metadata Support with a custom deserializer
        class OffsetMetadata < Base
          class << self
            # If needed installs the needed listener and initializes tracker
            #
            # @param _config [Karafka::Core::Configurable::Node] app config
            def post_setup(_config)
              ::Karafka::App.monitor.subscribe('app.running') do
                # Initialize the tracker prior to becoming multi-threaded
                ::Karafka::Processing::InlineInsights::Tracker.instance

                # Subscribe to the statistics reports and collect them
                ::Karafka.monitor.subscribe(
                  ::Karafka::Pro::Processing::OffsetMetadata::Listener.new
                )
              end
            end
          end
        end
      end
    end
  end
end
