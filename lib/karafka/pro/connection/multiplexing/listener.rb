# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
