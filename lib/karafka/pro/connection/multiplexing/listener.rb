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
    # Namespace for Pro connections related components
    module Connection
      # Namespace for Multiplexing management related components
      module Multiplexing
        # Listener used to connect listeners manager to the lifecycle events that are significant
        # to its operations
        class Listener
          def initialize
            @manager = App.config.internal.connection.manager
          end

          # Triggers connection manage subscription groups details noticing
          #
          # @param event [Karafka::Core::Monitoring::Event] event with statistics
          def on_statistics_emitted(event)
            @manager.notice(
              event[:subscription_group_id],
              event[:statistics]
            )
          end
        end
      end
    end
  end
end
