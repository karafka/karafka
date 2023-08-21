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
        class Patterns < Base
          # Listener used to run the periodic new topics detection via the runner tick engine.
          class Listener
            # Run the topics detection before first subscriptions start so we can immediately
            # subscribe to topics via patterns matching.
            #
            # @param _ [Karafka::Core::Monitoring::Event]
            def on_runner_before_call(_)
              detector.detect
            end

            # Runs detection once in a while as often as the ticking frequency
            #
            # @param _ [Karafka::Core::Monitoring::Event]
            def on_runner_tick(_)
              detector.detect
            end

            private

            # Creates detector upon first usage.
            # @return [Detector] new topics detector
            # @note We do not create it in the initializer because we may not have the routing
            #   defined at this stage yet. We do know however that it will be defined on the first
            #   usage of listener.
            def detector
              @detector ||= Detector.new
            end
          end
        end
      end
    end
  end
end
