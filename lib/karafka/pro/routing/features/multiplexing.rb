# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Namespace for Pro routing enhancements
    module Routing
      # Namespace for additional Pro features
      module Features
        # Multiplexing allows for creating multiple subscription groups for the same topic inside
        # of the same subscription group allowing for better parallelism with limited number
        # of processes
        class Multiplexing < Base
          class << self
            # @param _config [Karafka::Core::Configurable::Node] app config node
            def pre_setup(_config)
              # Make sure we use proper unique validator for topics definitions
              ::Karafka::Contracts::ConsumerGroup.singleton_class.prepend(
                Patches::Contracts::ConsumerGroup
              )
            end

            # If needed installs the needed listener and initializes tracker
            #
            # @param _config [Karafka::Core::Configurable::Node] app config
            def post_setup(_config)
              ::Karafka::App.monitor.subscribe('app.running') do
                # Do not install the manager and listener to control multiplexing unless there is
                # multiplexing enabled and it is dynamic.
                # We only need to control multiplexing when it is in a dynamic state
                next unless ::Karafka::App
                            .subscription_groups
                            .values
                            .flat_map(&:itself)
                            .any? { |sg| sg.multiplexing? && sg.multiplexing.dynamic? }

                # Subscribe for events and possibility to manage via the Pro connection manager
                # that supports multiplexing
                ::Karafka.monitor.subscribe(
                  ::Karafka::Pro::Connection::Multiplexing::Listener.new
                )
              end
            end
          end
        end
      end
    end
  end
end
