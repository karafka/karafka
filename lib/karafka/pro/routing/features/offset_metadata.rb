# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
